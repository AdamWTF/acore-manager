#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/acore-sleep-lib.sh"

require_sleep_enabled
require_sleep_command ss
require_sleep_command ps
require_sleep_command pgrep
ensure_sleep_state_dir

last_activity_file="$SLEEP_STATE_DIR/last-world-activity"
date +%s > "$last_activity_file"

sleep_log "Sleep monitor started"
sleep_log "World ports: $WORLD_PORTS; idle timeout: $SLEEP_IDLE_TIMEOUT seconds"

while true; do
  connections="$(world_connection_count)"

  if [[ "$connections" -gt 0 ]]; then
    date +%s > "$last_activity_file"
    sleep_log "World connection activity detected: $connections"
  else
    last_activity="$(cat "$last_activity_file" 2>/dev/null || date +%s)"
    current_time="$(date +%s)"
    idle_time=$((current_time - last_activity))
    sleep_log "No world connections; idle for $idle_time seconds"

    if [[ "$idle_time" -ge "$SLEEP_IDLE_TIMEOUT" ]]; then
      "$SCRIPT_DIR/acore-sleep-freeze.sh" || true
    fi
  fi

  sleep "$SLEEP_CHECK_INTERVAL"
done
