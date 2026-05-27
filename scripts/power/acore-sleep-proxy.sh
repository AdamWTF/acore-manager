#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/acore-sleep-lib.sh"

require_sleep_enabled
require_sleep_command socat

if [[ "$AUTH_PUBLIC_PORT" == "$AUTH_BACKEND_PORT" ]]; then
  die "AUTH_PUBLIC_PORT and AUTH_BACKEND_PORT must differ when sleep proxy is enabled"
fi

thaw_script="$SCRIPT_DIR/acore-sleep-thaw.sh"
[[ -x "$thaw_script" ]] || die "sleep thaw script is not executable: $thaw_script"

sleep_log "Sleep proxy started on ${SLEEP_PROXY_BIND_HOST}:${AUTH_PUBLIC_PORT} -> ${AUTH_BACKEND_HOST}:${AUTH_BACKEND_PORT}"

exec socat -v -v \
  "TCP4-LISTEN:${AUTH_PUBLIC_PORT},bind=${SLEEP_PROXY_BIND_HOST},fork,reuseaddr" \
  "SYSTEM:bash -c '$thaw_script --quiet >&2; exec socat -v -v STDIO TCP4:${AUTH_BACKEND_HOST}:${AUTH_BACKEND_PORT}'"
