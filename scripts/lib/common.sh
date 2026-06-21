#!/usr/bin/env bash
set -Eeuo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACM_REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"

ACM_DEFAULT_CONFIG="$ACM_REPO_ROOT/config/defaults/manager.conf.example"
ACM_LOCAL_CONFIG="$ACM_REPO_ROOT/config/local/manager.conf"

if [[ ! -f "$ACM_DEFAULT_CONFIG" ]]; then
  echo "Missing default config: $ACM_DEFAULT_CONFIG" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ACM_DEFAULT_CONFIG"

if [[ -f "$ACM_LOCAL_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$ACM_LOCAL_CONFIG"
fi

# SOURCE_ROOT is the parent directory for source checkouts.
SOURCE_ROOT="$ACM_ROOT/source"

# ACORE_SOURCE_DIR is the AzerothCore git checkout.
ACORE_SOURCE_DIR="$SOURCE_ROOT/azerothcore"

# MODULES_DIR lives inside the AzerothCore checkout.
MODULES_DIR="$ACORE_SOURCE_DIR/modules"

# Backwards-compatible alias for scripts that still expect SOURCE_DIR to mean
# the AzerothCore checkout. Do not use SOURCE_DIR for the parent directory.
SOURCE_DIR="$ACORE_SOURCE_DIR"

BUILD_DIR="$ACM_ROOT/build"
RELEASES_DIR="$ACM_ROOT/releases"
CURRENT_LINK="$ACM_ROOT/current"
CURRENT_DIR="$CURRENT_LINK"
SHARED_DIR="$ACM_ROOT/shared"
BACKUP_DIR="$ACM_ROOT/backups"
MODULE_CONFIG_DIR="$CONFIG_DIR/modules"
SHARED_LOG_DIR="$SHARED_DIR/logs"

log() {
  echo
  echo "================================================================"
  echo "$1"
  echo "================================================================"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

validate_current_runtime() {
  local current_target

  [[ -L "$CURRENT_LINK" ]] || die "CURRENT_LINK is not a symlink: $CURRENT_LINK
Create a release, list releases, then switch to one:
  ./bin/acore-manager create-release
  ./bin/acore-manager list-releases
  sudo ./bin/acore-manager switch-release <release-name>"

  current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
  [[ -n "$current_target" && -d "$current_target" ]] || die "CURRENT_LINK does not point to a release: $CURRENT_LINK"

  case "$current_target" in
    "$BUILD_DIR"/staging|"$BUILD_DIR"/staging/*)
      die "CURRENT_LINK points to build staging, which is not a runtime path: $current_target"
      ;;
  esac

  case "$current_target" in
    "$RELEASES_DIR"/*)
      ;;
    *)
      die "CURRENT_LINK must point under RELEASES_DIR ($RELEASES_DIR), got: $current_target"
      ;;
  esac

  [[ -x "$CURRENT_LINK/bin/authserver" ]] || die "authserver is missing or not executable: $CURRENT_LINK/bin/authserver"
  [[ -x "$CURRENT_LINK/bin/worldserver" ]] || die "worldserver is missing or not executable: $CURRENT_LINK/bin/worldserver"
}

validate_systemd_runtime_path() {
  local service="$1"
  local unit_text

  command -v systemctl >/dev/null 2>&1 || die "systemctl is not available"

  unit_text="$(systemctl cat "$service" 2>/dev/null || true)"
  if [[ -z "$unit_text" ]]; then
    die "systemd unit is not installed or cannot be read: $service"
  fi

  if grep -q 'build/staging' <<<"$unit_text"; then
    die "systemd unit $service still points at build/staging.
Fix installed service templates before starting or restarting services:
  sudo ./bin/acore-manager fix-runtime-paths
  sudo ./bin/acore-manager fix-runtime-paths --apply
Then restart explicitly when ready."
  fi

  if ! grep -q "$CURRENT_LINK/bin/" <<<"$unit_text"; then
    echo "WARN: systemd unit $service does not reference $CURRENT_LINK/bin"
    echo "      Review with: systemctl cat $service"
  fi
}

validate_systemd_runtime_paths() {
  validate_systemd_runtime_path "$AUTH_SERVICE"
  validate_systemd_runtime_path "$WORLD_SERVICE"
}

is_truthy() {
  case "${1:-}" in
    true|TRUE|yes|YES|1|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sleep_enabled() {
  is_truthy "${SLEEP_ENABLED:-false}"
}

sleep_thaw_if_enabled() {
  local thaw_script="$ACM_REPO_ROOT/scripts/power/acore-sleep-thaw.sh"

  if sleep_enabled && [[ -x "$thaw_script" ]]; then
    "$thaw_script" --quiet || echo "WARN: unable to thaw sleep-managed processes"
  fi
}

systemd_available() {
  command -v systemctl >/dev/null 2>&1
}

systemd_unit_exists() {
  local service="$1"

  systemd_available || return 1
  systemctl list-unit-files "$service" --no-legend 2>/dev/null | awk -v service="$service" '$1 == service { found = 1 } END { exit !found }' && return 0
  systemctl cat "$service" >/dev/null 2>&1 && return 0
  return 1
}

unit_active() {
  local service="$1"

  systemd_available || return 1
  systemctl is-active --quiet "$service" 2>/dev/null
}

unit_failed() {
  local service="$1"

  systemd_available || return 1
  systemctl is-failed --quiet "$service" 2>/dev/null
}

unit_state() {
  local service="$1"

  if ! systemd_available; then
    echo "systemctl-unavailable"
    return
  fi

  systemctl is-active "$service" 2>/dev/null || true
}

stop_unit_if_present() {
  local service="$1"
  local label="${2:-$service}"

  if ! systemd_available; then
    echo "WARN: systemctl is not available; skipped $label"
    return 0
  fi

  if ! systemd_unit_exists "$service"; then
    echo "Skipping $label: unit not installed ($service)"
    return 0
  fi

  if unit_active "$service" || unit_failed "$service"; then
    echo "Stopping $label: $service"
    systemctl stop "$service" || return 1
  else
    echo "Skipping $label: state=$(unit_state "$service") ($service)"
  fi
}

service_main_pid() {
  local service="$1"
  local pid=""

  if systemd_available; then
    pid="$(systemctl show -P MainPID "$service" 2>/dev/null || true)"
    if [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 0 ]]; then
      echo "$pid"
      return
    fi
  fi
}

process_command_matches() {
  local pid="$1"
  local binary="$2"
  local command_line

  command_line="$(ps -o args= -p "$pid" 2>/dev/null || true)"
  [[ "$command_line" == *"/$binary"* || "$command_line" == "$binary"* ]]
}

runtime_pids_for_service() {
  local service="$1"
  local binary="$2"
  local pid
  local seen=" "

  pid="$(service_main_pid "$service")"
  if [[ -n "$pid" ]]; then
    echo "$pid"
    seen+=" $pid "
  fi

  command -v pgrep >/dev/null 2>&1 || return 0

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    [[ "$seen" == *" $pid "* ]] && continue
    if process_command_matches "$pid" "$binary"; then
      echo "$pid"
      seen+=" $pid "
    fi
  done < <(pgrep -x "$binary" 2>/dev/null || true)

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    [[ "$seen" == *" $pid "* ]] && continue
    if process_command_matches "$pid" "$binary"; then
      echo "$pid"
      seen+=" $pid "
    fi
  done < <(pgrep -f "$CURRENT_LINK/bin/$binary" 2>/dev/null || true)
}

auth_pids() {
  runtime_pids_for_service "$AUTH_SERVICE" "authserver"
}

world_pids() {
  runtime_pids_for_service "$WORLD_SERVICE" "worldserver"
}

process_state() {
  local pid="$1"

  ps -o state= -p "$pid" 2>/dev/null | tr -d ' ' || true
}

process_is_frozen() {
  local pid="$1"
  local state

  [[ -n "$pid" ]] || return 1
  state="$(process_state "$pid")"
  [[ "$state" == *T* ]]
}

child_pids() {
  local pid="$1"

  pgrep -P "$pid" 2>/dev/null || true
}

send_signal_to_tree() {
  local signal="$1"
  local pid="$2"
  local child

  for child in $(child_pids "$pid"); do
    kill "-$signal" "$child" 2>/dev/null || true
  done
  kill "-$signal" "$pid" 2>/dev/null || true
}

thaw_frozen_pids() {
  local label="$1"
  shift
  local pid state thawed=false

  for pid in "$@"; do
    [[ -n "$pid" ]] || continue
    state="$(process_state "$pid")"
    if [[ -z "$state" ]]; then
      echo "Skipping $label process: already gone (pid=$pid)"
    elif [[ "$state" == *T* ]]; then
      echo "Thawing $label process: pid=$pid state=$state"
      send_signal_to_tree CONT "$pid"
      thawed=true
    else
      echo "Skipping $label process: not frozen (pid=$pid state=$state)"
    fi
  done

  [[ "$thawed" == "true" ]]
}

lock_env_name() {
  local name="$1"

  tr '[:lower:]-' '[:upper:]_' <<<"ACM_LOCK_HELD_$name"
}

acquire_acm_lock() {
  local name="$1"
  local env_name lock_dir lock_file meta_file fd_var fd held_by

  env_name="$(lock_env_name "$name")"
  if [[ "${!env_name:-}" == "true" ]]; then
    return 0
  fi

  command -v flock >/dev/null 2>&1 || die "flock is not available; install util-linux"

  lock_dir="$ACM_ROOT/.locks"
  lock_file="$lock_dir/$name.lock"
  meta_file="$lock_dir/$name.lock.meta"
  fd_var="ACM_LOCK_FD_${name//[^A-Za-z0-9_]/_}"

  mkdir -p "$lock_dir"
  eval "exec {${fd_var}}>\"\$lock_file\""
  fd="${!fd_var}"

  if ! flock -n "$fd"; then
    held_by="unknown"
    [[ -f "$meta_file" ]] && held_by="$(cat "$meta_file" 2>/dev/null || printf unknown)"
    die "another acore-manager $name operation is already running
Lock: $lock_file
Held by:
$held_by"
  fi

  {
    echo "pid=$$"
    echo "command=$0 $*"
    echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "host=$(hostname 2>/dev/null || printf unknown)"
  } > "$meta_file"
}

export_acm_lock_held() {
  local name="$1"
  local env_name

  env_name="$(lock_env_name "$name")"
  export "$env_name=true"
}

resolved_path_or_empty() {
  local path="$1"

  readlink -f "$path" 2>/dev/null || true
}

require_absolute_path() {
  local path="$1"
  local label="$2"

  [[ -n "$path" ]] || die "$label path is empty"
  [[ "$path" == /* ]] || die "$label must be an absolute path: $path"
}

path_is_within() {
  local child="$1"
  local parent="$2"
  local resolved_child resolved_parent

  resolved_child="$(resolved_path_or_empty "$child")"
  resolved_parent="$(resolved_path_or_empty "$parent")"
  [[ -n "$resolved_child" && -n "$resolved_parent" ]] || return 1

  case "$resolved_child" in
    "$resolved_parent"|"$resolved_parent"/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

path_must_not_be_dangerous() {
  local path="$1"
  local label="$2"
  local resolved

  require_absolute_path "$path" "$label"
  resolved="$(resolved_path_or_empty "$path")"

  case "$path" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/sys|/tmp|/usr|/var)
      die "$label path is too broad to modify: $path"
      ;;
  esac

  if [[ -n "$resolved" ]]; then
    case "$resolved" in
      /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/sys|/tmp|/usr|/var)
        die "$label resolves to a dangerous path: $resolved"
        ;;
    esac
  fi
}

resolved_current_target() {
  if [[ -L "$CURRENT_LINK" ]]; then
    resolved_path_or_empty "$CURRENT_LINK"
  fi
}

current_points_inside_build_dir() {
  local current_target

  current_target="$(resolved_current_target)"
  [[ -n "$current_target" ]] || return 1
  path_is_within "$current_target" "$BUILD_DIR"
}

require_not_symlink_dir() {
  local path="$1"
  local label="$2"

  [[ ! -L "$path" ]] || die "$label must not be a symlink for destructive operations: $path"
}

require_safe_build_dir() {
  local expected_build_dir="$ACM_ROOT/build"

  require_absolute_path "$BUILD_DIR" "BUILD_DIR"
  path_must_not_be_dangerous "$BUILD_DIR" "BUILD_DIR"
  [[ "$BUILD_DIR" == "$expected_build_dir" ]] || die "BUILD_DIR must be derived as ACM_ROOT/build; got $BUILD_DIR expected $expected_build_dir"
  require_not_symlink_dir "$BUILD_DIR" "BUILD_DIR"

  for protected_path in "$ACM_ROOT" "$SOURCE_ROOT" "$ACORE_SOURCE_DIR" "$MODULES_DIR" "$RELEASES_DIR" "$SHARED_DIR" "$BACKUP_DIR" "$CONFIG_DIR" "$DATADIR"; do
    [[ "$BUILD_DIR" != "$protected_path" ]] || die "BUILD_DIR overlaps protected path: $protected_path"
  done

  if current_points_inside_build_dir; then
    die "CURRENT_LINK resolves inside BUILD_DIR; refusing to clean build output: $(resolved_current_target)"
  fi
}

service_activity_summary() {
  local auth_state world_state

  auth_state="$(unit_state "$AUTH_SERVICE")"
  world_state="$(unit_state "$WORLD_SERVICE")"
  echo "auth=$auth_state world=$world_state"
}

services_are_active() {
  unit_active "$AUTH_SERVICE" || unit_active "$WORLD_SERVICE"
}

require_services_inactive_or_safe_stop_first() {
  local safe_stop_first="$1"

  if ! services_are_active; then
    return 0
  fi

  if [[ "$safe_stop_first" == "true" ]]; then
    "$ACM_REPO_ROOT/scripts/runtime/acore-safe-stop.sh"
    return
  fi

  die "auth/world services are active ($(service_activity_summary)); rerun with --safe-stop-first or stop services explicitly"
}
