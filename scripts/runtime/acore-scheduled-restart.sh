#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

usage() {
  cat <<EOF
Usage:
  $0

Runs the normal acore-manager restart workflow for cron-managed scheduled restarts.
EOF
}

if [[ "$#" -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown scheduled-restart option: $1"
      ;;
  esac
fi

restart_script="$ACM_REPO_ROOT/scripts/runtime/acore-restart.sh"
[[ -x "$restart_script" ]] || die "restart script is missing or not executable: $restart_script"

log "Starting scheduled AzerothCore restart"
echo "Started at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$restart_script"

echo "Completed at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Scheduled AzerothCore restart complete"
