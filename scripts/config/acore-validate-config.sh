#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

errors=0

require_var() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    echo "ERROR: $name is not set"
    errors=$((errors + 1))
  else
    echo "OK: $name is set"
  fi
}

require_cmd() {
  local name="$1"

  if command -v "$name" >/dev/null 2>&1; then
    echo "OK: command found: $name"
  else
    echo "ERROR: command missing: $name"
    errors=$((errors + 1))
  fi
}

check_path() {
  local name="$1"
  local path="$2"

  if [[ -d "$path" ]]; then
    echo "OK: $name exists: $path"
  elif [[ -e "$path" ]]; then
    echo "WARN: $name exists but is not a directory: $path"
  else
    echo "WARN: $name does not exist yet: $path"
  fi
}

check_source_checkout() {
  if [[ -d "$ACORE_SOURCE_DIR/.git" ]]; then
    echo "OK: ACORE_SOURCE_DIR is a git checkout: $ACORE_SOURCE_DIR"
  elif [[ -e "$ACORE_SOURCE_DIR" ]]; then
    echo "WARN: ACORE_SOURCE_DIR exists but is not a git checkout: $ACORE_SOURCE_DIR"
  else
    echo "WARN: ACORE_SOURCE_DIR does not exist yet; run acore-update-source.sh to clone it: $ACORE_SOURCE_DIR"
  fi
}

check_file_warn() {
  local name="$1"
  local path="$2"

  if [[ -f "$path" ]]; then
    echo "OK: $name exists: $path"
  else
    echo "WARN: $name does not exist yet: $path"
  fi
}

warn_missing_cmd() {
  local name="$1"

  if command -v "$name" >/dev/null 2>&1; then
    echo "OK: command found: $name"
  else
    echo "WARN: command missing: $name"
  fi
}

configured_realm_port() {
  local auth_conf="$CONFIG_DIR/authserver.conf"

  [[ -f "$auth_conf" ]] || return 0
  awk -F= '
    /^[[:space:]]*RealmServerPort[[:space:]]*=/ {
      value = $2
      sub(/[[:space:]]*.*/, "", value)
      gsub(/"/, "", value)
      print value
      exit
    }
  ' "$auth_conf"
}

check_active_config_links() {
  if [[ ! -L "$CURRENT_LINK" ]]; then
    echo "WARN: CURRENT_LINK is not set yet: $CURRENT_LINK"
    return
  fi

  local current_target
  current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
  if [[ -z "$current_target" || ! -d "$current_target" ]]; then
    echo "WARN: CURRENT_LINK does not point to a release: $CURRENT_LINK"
    return
  fi

  echo "OK: CURRENT_LINK points to: $current_target"

  check_link_target "$CURRENT_LINK/etc/authserver.conf" "$CONFIG_DIR/authserver.conf"
  check_link_target "$CURRENT_LINK/etc/worldserver.conf" "$CONFIG_DIR/worldserver.conf"
  check_link_target "$CURRENT_LINK/etc/modules" "$MODULE_CONFIG_DIR"
}

check_link_target() {
  local link_path="$1"
  local expected_path="$2"

  if [[ ! -L "$link_path" ]]; then
    echo "WARN: expected symlink is missing: $link_path"
    return
  fi

  local actual_target expected_target
  actual_target="$(readlink -f "$link_path" 2>/dev/null || true)"
  expected_target="$(readlink -f "$expected_path" 2>/dev/null || true)"

  if [[ -n "$actual_target" && "$actual_target" == "$expected_target" ]]; then
    echo "OK: $link_path -> $expected_path"
  else
    echo "WARN: $link_path points to $actual_target, expected $expected_path"
  fi
}

check_data_dirs() {
  for name in dbc maps vmaps mmaps; do
    if [[ -d "$DATADIR/$name" ]]; then
      echo "OK: data directory exists: $DATADIR/$name"
    else
      echo "WARN: data directory missing: $DATADIR/$name"
    fi
  done
}

check_sleep_config() {
  log "Idle Sleep"

  if ! sleep_enabled; then
    echo "OK: sleep mode is disabled"
    return
  fi

  echo "OK: sleep mode is enabled"

  for name in \
    SLEEP_CHECK_INTERVAL \
    SLEEP_IDLE_TIMEOUT \
    MIN_UPTIME_BEFORE_SLEEP \
    REQUIRE_WORLDSERVER_READY \
    REQUIRE_PLAYERBOTS_READY \
    REQUIRE_BOT_LEVEL_BRACKETS_READY \
    AUTH_PUBLIC_PORT \
    AUTH_BACKEND_PORT \
    AUTH_BACKEND_HOST \
    SLEEP_PROXY_BIND_HOST \
    WORLD_PORTS \
    SLEEP_STATE_DIR; do
    require_var "$name"
  done

  for name in socat ss pgrep ps logger journalctl; do
    warn_missing_cmd "$name"
  done

  if [[ "${AUTH_PUBLIC_PORT:-}" == "${AUTH_BACKEND_PORT:-}" ]]; then
    echo "WARN: AUTH_PUBLIC_PORT and AUTH_BACKEND_PORT are the same; the sleep proxy needs separate public and backend ports"
  fi

  local realm_port
  realm_port="$(configured_realm_port)"
  if [[ -z "$realm_port" ]]; then
    echo "WARN: unable to confirm RealmServerPort in $CONFIG_DIR/authserver.conf"
    echo "      For sleep mode, authserver should listen on AUTH_BACKEND_PORT ($AUTH_BACKEND_PORT), while the proxy listens on AUTH_PUBLIC_PORT ($AUTH_PUBLIC_PORT)."
  elif [[ "$realm_port" == "$AUTH_PUBLIC_PORT" ]]; then
    echo "WARN: authserver.conf RealmServerPort is still the public proxy port ($AUTH_PUBLIC_PORT)"
    echo "      Change it to AUTH_BACKEND_PORT ($AUTH_BACKEND_PORT) before starting the sleep proxy."
  elif [[ "$realm_port" == "$AUTH_BACKEND_PORT" ]]; then
    echo "OK: authserver.conf RealmServerPort uses backend port: $AUTH_BACKEND_PORT"
  else
    echo "WARN: authserver.conf RealmServerPort is $realm_port, expected AUTH_BACKEND_PORT ($AUTH_BACKEND_PORT)"
  fi
}

check_auto_restart_config() {
  local field_count

  log "Automatic Restarts"

  if ! is_truthy "${AUTO_RESTART_ENABLED:-false}"; then
    echo "OK: automatic restarts are disabled"
  else
    echo "OK: automatic restarts are enabled"
  fi

  require_var AUTO_RESTART_ENABLED
  require_var AUTO_RESTART_CRON
  require_var AUTO_RESTART_USER

  field_count="$(awk '{ print NF }' <<<"${AUTO_RESTART_CRON:-}")"
  if [[ "$field_count" -eq 5 ]]; then
    echo "OK: AUTO_RESTART_CRON uses 5-field cron syntax: $AUTO_RESTART_CRON"
  else
    echo "ERROR: AUTO_RESTART_CRON must use 5-field cron syntax, got: ${AUTO_RESTART_CRON:-}"
    errors=$((errors + 1))
  fi

  if [[ "${AUTO_RESTART_USER:-}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "OK: AUTO_RESTART_USER looks valid: $AUTO_RESTART_USER"
  else
    echo "ERROR: AUTO_RESTART_USER contains unsupported characters: ${AUTO_RESTART_USER:-}"
    errors=$((errors + 1))
  fi
}

log "Required Variables"
for name in \
  ACM_ROOT \
  ACORE_REPO \
  ACORE_BRANCH \
  ACORE_USER \
  ACORE_GROUP \
  AUTH_SERVICE \
  WORLD_SERVICE \
  AUTO_RESTART_ENABLED \
  AUTO_RESTART_CRON \
  AUTO_RESTART_USER \
  SLEEP_ENABLED \
  MYSQL_HOST \
  MYSQL_PORT \
  MYSQL_AUTH_DB \
  MYSQL_WORLD_DB \
  MYSQL_CHAR_DB \
  DATADIR \
  CONFIG_DIR \
  BUILD_TYPE \
  BUILD_THREADS; do
  require_var "$name"
done

log "Required Commands"
for name in git cmake make mysql systemctl; do
  require_cmd "$name"
done

log "Paths"
check_path "ACM_ROOT" "$ACM_ROOT"
check_path "SOURCE_ROOT" "$SOURCE_ROOT"
check_source_checkout
check_path "DATADIR" "$DATADIR"
check_path "CONFIG_DIR" "$CONFIG_DIR"
check_path "MODULE_CONFIG_DIR" "$MODULE_CONFIG_DIR"
check_file_warn "authserver.conf" "$CONFIG_DIR/authserver.conf"
check_file_warn "worldserver.conf" "$CONFIG_DIR/worldserver.conf"
check_active_config_links
check_data_dirs
check_sleep_config
check_auto_restart_config

log "Services"
require_var AUTH_SERVICE
require_var WORLD_SERVICE

if [[ "$errors" -gt 0 ]]; then
  die "config validation failed with $errors error(s)"
fi

echo
echo "Config validation completed with no blocking errors."
