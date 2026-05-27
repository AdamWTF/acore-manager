#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v systemctl >/dev/null 2>&1 || die "systemctl is not available"

log "Stopping AzerothCore services"
sleep_thaw_if_enabled

echo "Stopping world service: $WORLD_SERVICE"
systemctl stop "$WORLD_SERVICE" || die "failed to stop world service: $WORLD_SERVICE"

echo "Stopping auth service: $AUTH_SERVICE"
systemctl stop "$AUTH_SERVICE" || die "failed to stop auth service: $AUTH_SERVICE"

echo
echo "Auth service state: $(systemctl is-active "$AUTH_SERVICE" 2>/dev/null || true)"
echo "World service state: $(systemctl is-active "$WORLD_SERVICE" 2>/dev/null || true)"
