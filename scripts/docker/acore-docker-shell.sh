#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

[[ "$#" -ge 1 ]] || die "usage: ./bin/acore-manager docker shell <service> [shell]"

service="$1"
shift
shell_name="${1:-bash}"

require_cmd docker
ensure_compose_override
mapfile -t compose_args < <(compose_project_args)

docker "${compose_args[@]}" exec "$service" "$shell_name"
