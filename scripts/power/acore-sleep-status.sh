#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/acore-sleep-lib.sh"

show_pids() {
  local label="$1"
  shift
  local pid state

  if [[ "$#" -eq 0 ]]; then
    echo "$label PIDs: none detected"
    return
  fi

  echo "$label PIDs:"
  for pid in "$@"; do
    state="$(ps -o state= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
    [[ -n "$state" ]] || state="unknown"
    echo "  $pid state=$state"
  done
}

log "Sleep Configuration"
echo "Enabled: ${SLEEP_ENABLED:-false}"
echo "Check interval: ${SLEEP_CHECK_INTERVAL:-}"
echo "Idle timeout: ${SLEEP_IDLE_TIMEOUT:-}"
echo "Startup grace: ${MIN_UPTIME_BEFORE_SLEEP:-600}"
echo "Require world ready: ${REQUIRE_WORLDSERVER_READY:-1}"
echo "Require PlayerBots ready: ${REQUIRE_PLAYERBOTS_READY:-1}"
echo "Require BotLevelBrackets ready: ${REQUIRE_BOT_LEVEL_BRACKETS_READY:-1}"
echo "Auth public: ${SLEEP_PROXY_BIND_HOST:-}:${AUTH_PUBLIC_PORT:-}"
echo "Auth backend: ${AUTH_BACKEND_HOST:-}:${AUTH_BACKEND_PORT:-}"
echo "World ports: ${WORLD_PORTS:-}"
echo "State dir: ${SLEEP_STATE_DIR:-}"

log "Sleep Services"
if command -v systemctl >/dev/null 2>&1; then
  for service in acore-sleep-proxy.service acore-sleep-monitor.service; do
    echo "$service active: $(systemctl is-active "$service" 2>/dev/null || true)"
    echo "$service enabled: $(systemctl is-enabled "$service" 2>/dev/null || true)"
  done
else
  echo "WARN: systemctl is not available"
fi

log "Ports"
if command -v ss >/dev/null 2>&1; then
  if port_is_listening "$AUTH_PUBLIC_PORT"; then
    echo "$AUTH_PUBLIC_PORT: listening"
  else
    echo "$AUTH_PUBLIC_PORT: not detected"
  fi

  if port_is_listening "$AUTH_BACKEND_PORT"; then
    echo "$AUTH_BACKEND_PORT: listening"
  else
    echo "$AUTH_BACKEND_PORT: not detected"
  fi

  echo "Established world connections: $(world_connection_count)"
else
  echo "WARN: ss is not available"
fi

log "Processes"
if command -v ps >/dev/null 2>&1 && command -v pgrep >/dev/null 2>&1; then
  mapfile -t auth < <(auth_pids)
  mapfile -t world < <(world_pids)
  show_pids "Auth" "${auth[@]}"
  show_pids "World" "${world[@]}"
  if [[ "${#world[@]}" -gt 0 ]]; then
    echo "World uptime seconds: $(process_uptime_seconds "${world[0]}")"
  fi
else
  echo "WARN: ps or pgrep is not available"
fi
