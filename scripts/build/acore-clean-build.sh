#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

DRY_RUN=false

usage() {
  cat <<EOF
Usage:
  $0 [--dry-run]

Removes generated build artifacts only. Source, modules, releases, shared
configs, shared data, logs, backups, systemd units, and databases are kept.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

if [[ "$DRY_RUN" != "true" ]]; then
  acquire_acm_lock build
fi
require_safe_build_dir

current_target="$(resolved_current_target)"
[[ -n "$current_target" ]] || current_target="none"

build_entries=()
if [[ -d "$BUILD_DIR" ]]; then
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    build_entries+=("$entry")
  done < <(find "$BUILD_DIR" -mindepth 1 -maxdepth 1 -print 2>/dev/null | sort)
fi

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry-run clean build"
else
  log "Clean build"
fi

echo "Build directory: $BUILD_DIR"
echo "Current release: $current_target"
echo "Services active: $(service_activity_summary)"
echo

if [[ "${#build_entries[@]}" -eq 0 ]]; then
  echo "Would remove: nothing"
else
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would remove:"
  else
    echo "Removing:"
  fi
  for entry in "${build_entries[@]}"; do
    echo "  $entry"
  done
fi

echo
echo "Would keep:"
echo "  $ACORE_SOURCE_DIR"
echo "  $MODULES_DIR"
echo "  $RELEASES_DIR"
echo "  $CURRENT_LINK"
echo "  $CONFIG_DIR"
echo "  $DATADIR"
echo "  $BACKUP_DIR"
echo
echo "No services will be stopped or restarted."

if services_are_active; then
  echo "WARN: services are active; clean-build does not affect the active release when CURRENT_LINK is outside BUILD_DIR."
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo
  echo "Dry-run only. Re-run without --dry-run to remove generated build artifacts."
  exit 0
fi

mkdir -p "$BUILD_DIR"
for entry in "${build_entries[@]}"; do
  rm -rf -- "$entry"
done
mkdir -p "$BUILD_DIR"

echo
echo "Clean build completed."
