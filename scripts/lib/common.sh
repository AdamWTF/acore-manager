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
