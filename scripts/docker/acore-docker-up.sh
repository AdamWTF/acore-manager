#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

require_cmd docker
ensure_compose_override
mapfile -t compose_args < <(compose_project_args)

log "Starting AzerothCore Docker services"
if is_truthy "$MYSQL_EXTERNAL"; then
  echo "Using external MySQL host: $MYSQL_HOST:$MYSQL_PORT"
  docker "${compose_args[@]}" up -d --no-deps "$SERVICE_AUTHSERVER" "$SERVICE_WORLDSERVER" "$@"
else
  docker "${compose_args[@]}" --profile local-db up -d "$SERVICE_DATABASE" "$SERVICE_AUTHSERVER" "$SERVICE_WORLDSERVER" "$@"
fi
