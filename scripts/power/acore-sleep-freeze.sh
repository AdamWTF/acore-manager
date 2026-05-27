#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/acore-sleep-lib.sh"

require_sleep_enabled
require_sleep_command ps
require_sleep_command pgrep

freeze_label() {
  local label="$1"
  shift
  local pid

  for pid in "$@"; do
    [[ -n "$pid" ]] || continue
    if process_is_frozen "$pid"; then
      sleep_log "$label process is already frozen: $pid"
    else
      send_signal_to_tree STOP "$pid"
      sleep_log "Froze $label process: $pid"
    fi
  done
}

mapfile -t auth < <(auth_pids)
mapfile -t world < <(world_pids)

if [[ "${#auth[@]}" -eq 0 && "${#world[@]}" -eq 0 ]]; then
  die "no authserver or worldserver processes were found"
fi

freeze_label "authserver" "${auth[@]}"
freeze_label "worldserver" "${world[@]}"
