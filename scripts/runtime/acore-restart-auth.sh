#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v systemctl >/dev/null 2>&1 || die "systemctl is not available"
validate_current_runtime

log "Restarting auth service"

echo "Restarting auth service: $AUTH_SERVICE"
systemctl restart "$AUTH_SERVICE" || die "failed to restart auth service: $AUTH_SERVICE"

echo
systemctl --no-pager --full status "$AUTH_SERVICE" || true
