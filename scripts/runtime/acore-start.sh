#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v systemctl >/dev/null 2>&1 || die "systemctl is not available"
validate_current_runtime
validate_systemd_runtime_paths

log "Starting AzerothCore services"

echo "Starting auth service: $AUTH_SERVICE"
systemctl start "$AUTH_SERVICE" || die "failed to start auth service: $AUTH_SERVICE"

echo "Starting world service: $WORLD_SERVICE"
systemctl start "$WORLD_SERVICE" || die "failed to start world service: $WORLD_SERVICE"

echo
systemctl --no-pager --full status "$AUTH_SERVICE" || true
systemctl --no-pager --full status "$WORLD_SERVICE" || true
