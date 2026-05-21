#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v systemctl >/dev/null 2>&1 || die "systemctl is not available"

release_name="${1:-}"
[[ -n "$release_name" ]] || die "usage: $0 <release-name>"
[[ "$release_name" != *"/"* ]] || die "release name must not contain slashes: $release_name"

release_dir="$RELEASES_DIR/$release_name"
[[ -d "$release_dir" ]] || die "release does not exist: $release_dir"
[[ -x "$release_dir/bin/authserver" ]] || die "authserver is not executable in release: $release_dir/bin/authserver"
[[ -x "$release_dir/bin/worldserver" ]] || die "worldserver is not executable in release: $release_dir/bin/worldserver"

log "Switching active release"
echo "Release: $release_name"
echo "Path: $release_dir"

echo "Stopping world service: $WORLD_SERVICE"
systemctl stop "$WORLD_SERVICE" || die "failed to stop world service: $WORLD_SERVICE"

echo "Stopping auth service: $AUTH_SERVICE"
systemctl stop "$AUTH_SERVICE" || die "failed to stop auth service: $AUTH_SERVICE"

mkdir -p "$(dirname "$CURRENT_LINK")"
ln -sfn "$release_dir" "$CURRENT_LINK"
echo "Updated current link: $CURRENT_LINK -> $release_dir"

validate_current_runtime

link_configs_script="$ACM_REPO_ROOT/scripts/config/acore-link-shared-configs.sh"
[[ -x "$link_configs_script" ]] || die "shared config linker is not executable: $link_configs_script"
"$link_configs_script"

echo "Active runtime path: $CURRENT_LINK"

echo "Starting auth service: $AUTH_SERVICE"
systemctl start "$AUTH_SERVICE" || die "failed to start auth service: $AUTH_SERVICE"

echo "Starting world service: $WORLD_SERVICE"
systemctl start "$WORLD_SERVICE" || die "failed to start world service: $WORLD_SERVICE"

status_script="$ACM_REPO_ROOT/scripts/runtime/acore-status.sh"
if [[ -x "$status_script" ]]; then
  "$status_script"
else
  echo "Status script is not executable or not found: $status_script"
fi
