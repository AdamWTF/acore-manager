#!/usr/bin/env bash
set -Eeuo pipefail

SLEEP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SLEEP_LIB_DIR/../lib/common.sh"

require_sleep_enabled() {
  sleep_enabled || die "sleep mode is disabled; set SLEEP_ENABLED=\"true\" to use this command"
}

require_sleep_command() {
  local name="$1"

  command -v "$name" >/dev/null 2>&1 || die "required command is missing: $name"
}

ensure_sleep_state_dir() {
  mkdir -p "$SLEEP_STATE_DIR"
}

sleep_log() {
  local message="$1"

  logger -t acore-sleep "$message" 2>/dev/null || true
  echo "$(date '+%Y-%m-%d %H:%M:%S') $message"
}

service_main_pid() {
  local service="$1"
  local pid=""

  if command -v systemctl >/dev/null 2>&1; then
    pid="$(systemctl show -P MainPID "$service" 2>/dev/null || true)"
    if [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 0 ]]; then
      echo "$pid"
      return
    fi
  fi
}

runtime_pids_for_service() {
  local service="$1"
  local binary="$2"
  local pid

  pid="$(service_main_pid "$service")"
  if [[ -n "$pid" ]]; then
    echo "$pid"
    return
  fi

  pgrep -f "$CURRENT_LINK/bin/$binary" 2>/dev/null || true
}

auth_pids() {
  runtime_pids_for_service "$AUTH_SERVICE" "authserver"
}

world_pids() {
  runtime_pids_for_service "$WORLD_SERVICE" "worldserver"
}

process_is_frozen() {
  local pid="$1"

  [[ -n "$pid" ]] || return 1
  ps -o state= -p "$pid" 2>/dev/null | grep -q "T"
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

world_connection_count() {
  local total=0
  local port count

  require_sleep_command ss

  for port in $WORLD_PORTS; do
    count="$(ss -Htn state established "sport = :$port" 2>/dev/null | wc -l)"
    total=$((total + count))
  done

  echo "$total"
}

port_is_listening() {
  local port="$1"

  require_sleep_command ss
  ss -ltn "sport = :$port" 2>/dev/null | awk 'NR > 1 { found = 1 } END { exit !found }'
}
