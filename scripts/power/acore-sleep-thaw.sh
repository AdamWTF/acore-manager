#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/acore-sleep-lib.sh"

QUIET=false

usage() {
  cat <<EOF
Usage:
  $0 [--quiet]
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --quiet)
      QUIET=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

require_sleep_command ps
require_sleep_command pgrep

thaw_label() {
  local label="$1"
  shift
  local pid thawed=false

  for pid in "$@"; do
    [[ -n "$pid" ]] || continue
    if process_is_frozen "$pid"; then
      send_signal_to_tree CONT "$pid"
      thawed=true
      [[ "$QUIET" == "true" ]] || sleep_log "Thawed $label process: $pid"
    fi
  done

  if [[ "$thawed" != "true" && "$QUIET" != "true" ]]; then
    sleep_log "$label process is not frozen"
  fi
}

mapfile -t auth < <(auth_pids)
mapfile -t world < <(world_pids)

thaw_label "authserver" "${auth[@]}"
thaw_label "worldserver" "${world[@]}"

sleep 0.2
