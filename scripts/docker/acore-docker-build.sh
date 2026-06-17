#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

require_cmd docker
# shellcheck disable=SC1091
source "$SCRIPT_DIR/acore-docker-sync-modules.sh"

mapfile -t compose_args < <(compose_project_args)

log "Building AzerothCore Docker services"
docker "${compose_args[@]}" build "$@"
