#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

HOST_SHUTDOWN=false

usage() {
  cat <<EOF
Usage:
  $0 [--host-shutdown]

Safely stop AzerothCore for maintenance, poweroff, or reboot.

Options:
  --host-shutdown  Non-interactive mode for the systemd shutdown hook.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --host-shutdown)
      HOST_SHUTDOWN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown safe-stop option: $1"
      ;;
  esac
  shift
done

require_runtime_commands() {
  command -v ps >/dev/null 2>&1 || die "required command is missing: ps"
  command -v pgrep >/dev/null 2>&1 || die "required command is missing: pgrep"
  systemd_available || die "systemctl is not available"
}

show_detected_state() {
  local label="$1"
  local service="$2"
  shift 2
  local pid state

  echo "$label service: $service state=$(unit_state "$service")"
  if [[ "$#" -eq 0 ]]; then
    echo "$label processes: none detected"
    return
  fi

  echo "$label processes:"
  for pid in "$@"; do
    state="$(process_state "$pid")"
    [[ -n "$state" ]] || state="gone"
    echo "  pid=$pid state=$state"
  done
}

thaw_detected_processes() {
  local thawed=false

  if thaw_frozen_pids "authserver" "${auth[@]}"; then
    thawed=true
  fi

  if thaw_frozen_pids "worldserver" "${world[@]}"; then
    thawed=true
  fi

  if [[ "$thawed" == "true" ]]; then
    echo "Waiting briefly for thawed processes to resume"
    sleep 0.5
  fi
}

final_state_safe() {
  local failed=false
  local pid state

  mapfile -t auth < <(auth_pids)
  mapfile -t world < <(world_pids)

  if [[ "${#world[@]}" -gt 0 ]]; then
    for pid in "${world[@]}"; do
      state="$(process_state "$pid")"
      if [[ -n "$state" ]]; then
        echo "ERROR: worldserver process still exists after stop: pid=$pid state=$state"
        failed=true
      fi
    done
  fi

  if [[ "${#auth[@]}" -gt 0 ]]; then
    for pid in "${auth[@]}"; do
      state="$(process_state "$pid")"
      if [[ -n "$state" ]]; then
        echo "ERROR: authserver process still exists after stop: pid=$pid state=$state"
        failed=true
      fi
    done
  fi

  if unit_active "$WORLD_SERVICE"; then
    echo "ERROR: world service is still active: $WORLD_SERVICE"
    failed=true
  fi

  if unit_active "$AUTH_SERVICE"; then
    echo "ERROR: auth service is still active: $AUTH_SERVICE"
    failed=true
  fi

  [[ "$failed" != "true" ]]
}

require_runtime_commands

monitor_services=("acore-sleep-monitor.service" "azerothcore-monitor.service")
proxy_services=("acore-sleep-proxy.service" "azerothcore-auth-proxy.service")

log "Detecting AzerothCore shutdown state"
mapfile -t auth < <(auth_pids)
mapfile -t world < <(world_pids)
show_detected_state "Auth" "$AUTH_SERVICE" "${auth[@]}"
show_detected_state "World" "$WORLD_SERVICE" "${world[@]}"

log "Stopping sleep control services"
for service in "${monitor_services[@]}"; do
  stop_unit_if_present "$service" "sleep monitor" || die "failed to stop sleep monitor service: $service"
done

log "Thawing frozen AzerothCore processes"
thaw_detected_processes

log "Stopping AzerothCore services"
stop_unit_if_present "$WORLD_SERVICE" "world service" || die "failed to stop world service: $WORLD_SERVICE"
stop_unit_if_present "$AUTH_SERVICE" "auth service" || die "failed to stop auth service: $AUTH_SERVICE"
for service in "${proxy_services[@]}"; do
  stop_unit_if_present "$service" "sleep proxy" || die "failed to stop sleep proxy service: $service"
done

log "Verifying safe shutdown state"
if final_state_safe; then
  echo "Safe stop complete. AzerothCore is safe for host shutdown."
else
  die "safe-stop finished with an unsafe final state"
fi
