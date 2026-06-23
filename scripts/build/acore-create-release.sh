#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

acquire_acm_lock build
acquire_acm_lock release

command -v git >/dev/null 2>&1 || die "git is not available"

STAGING_DIR="$BUILD_DIR/staging"
[[ -d "$STAGING_DIR" ]] || die "staging directory does not exist: $STAGING_DIR"
validate_runtime_artifacts "$STAGING_DIR" "staging"

timestamp="$(date -u +%Y%m%d-%H%M%S)"
release_name="$timestamp"
release_dir="$RELEASES_DIR/$release_name"
release_info="$release_dir/metadata/release-info.txt"

if [[ -e "$release_dir" ]]; then
  die "release directory already exists: $release_dir"
fi

log "Creating release"
mkdir -p "$RELEASES_DIR"
mkdir -p "$release_dir"

if command -v rsync >/dev/null 2>&1; then
  rsync -a "$STAGING_DIR/" "$release_dir/"
else
  cp -a "$STAGING_DIR/." "$release_dir/"
fi

validate_runtime_artifacts "$release_dir" "release"

if [[ -d "$release_dir/etc" ]]; then
  mv "$release_dir/etc" "$release_dir/etc.dist"
  mkdir -p "$release_dir/etc"
  echo "Stored pristine config templates: $release_dir/etc.dist"
else
  mkdir -p "$release_dir/etc" "$release_dir/etc.dist"
  echo "No staged etc directory found; created empty etc and etc.dist directories."
fi

mkdir -p "$release_dir/metadata"

source_commit="unavailable"
if [[ -d "$ACORE_SOURCE_DIR/.git" ]]; then
  source_commit="$(git -C "$ACORE_SOURCE_DIR" rev-parse HEAD 2>/dev/null || printf 'unavailable')"
fi

{
  echo "Release: $release_name"
  echo "Build date UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Build type: $BUILD_TYPE"
  echo
  echo "Paths:"
  echo "  ACM_ROOT: $ACM_ROOT"
  echo "  SOURCE_ROOT: $SOURCE_ROOT"
  echo "  ACORE_SOURCE_DIR: $ACORE_SOURCE_DIR"
  echo "  MODULES_DIR: $MODULES_DIR"
  echo "  BUILD_DIR: $BUILD_DIR"
  echo "  STAGING_DIR: $STAGING_DIR"
  echo "  RELEASES_DIR: $RELEASES_DIR"
  echo "  RELEASE_DIR: $release_dir"
  echo "  CURRENT_LINK: $CURRENT_LINK"
  echo "  CONFIG_DIR: $CONFIG_DIR"
  echo "  MODULE_CONFIG_DIR: $MODULE_CONFIG_DIR"
  echo "  DATADIR: $DATADIR"
  echo
  echo "AzerothCore commit:"
  echo "  $source_commit"
  echo
  echo "Module commits:"
  if [[ -d "$MODULES_DIR" ]]; then
    found_module=false
    for module_dir in "$MODULES_DIR"/*; do
      [[ -d "$module_dir/.git" ]] || continue
      found_module=true
      module_name="$(basename "$module_dir")"
      module_commit="$(git -C "$module_dir" rev-parse HEAD 2>/dev/null || printf 'unavailable')"
      echo "  $module_name: $module_commit"
    done

    if [[ "$found_module" == "false" ]]; then
      echo "  none"
    fi
  else
    echo "  MODULES_DIR does not exist"
  fi
} > "$release_info"

echo
echo "Release created successfully."
echo "Release name: $release_name"
echo "Release path: $release_dir"
echo "Release metadata: $release_info"
