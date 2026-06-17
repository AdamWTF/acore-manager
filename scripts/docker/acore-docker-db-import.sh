#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

require_cmd docker
ensure_compose_override
mapfile -t compose_args < <(compose_project_args)

log "Running AzerothCore database import"
if is_truthy "$MYSQL_EXTERNAL"; then
  echo "Using external MySQL host: $MYSQL_HOST:$MYSQL_PORT"
  docker "${compose_args[@]}" run --rm --no-deps "$SERVICE_DB_IMPORT" "$@"
else
  docker "${compose_args[@]}" --profile local-db up -d "$SERVICE_DATABASE"
  docker "${compose_args[@]}" --profile local-db run --rm "$SERVICE_DB_IMPORT" "$@"
fi
