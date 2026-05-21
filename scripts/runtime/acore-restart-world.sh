#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v systemctl >/dev/null 2>&1 || die "systemctl is not available"
validate_current_runtime

log "Restarting world service"

echo "Restarting world service: $WORLD_SERVICE"
systemctl restart "$WORLD_SERVICE" || die "failed to restart world service: $WORLD_SERVICE"

echo
systemctl --no-pager --full status "$WORLD_SERVICE" || true
