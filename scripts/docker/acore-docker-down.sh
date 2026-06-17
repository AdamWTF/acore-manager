#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

require_cmd docker
ensure_compose_override
mapfile -t compose_args < <(compose_project_args)

log "Stopping AzerothCore Docker services"
docker "${compose_args[@]}" down "$@"
