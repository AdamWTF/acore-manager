#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

CLEAN=false
DRY_RUN=false

usage() {
  cat <<EOF
Usage:
  $0 [--clean] [--dry-run]

Runs the build workflow without creating a release, switching current, or
restarting services. Use --clean to remove generated build artifacts first.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --clean)
      CLEAN=true
      ;;
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
  export_acm_lock_held build
fi
require_safe_build_dir

log "Rebuild"
echo "Build directory: $BUILD_DIR"
echo "Source directory: $ACORE_SOURCE_DIR"
echo "Modules directory: $MODULES_DIR"
echo "Staging directory: $BUILD_DIR/staging"
echo "Runtime install prefix baked into build: $CURRENT_LINK"
echo "Services active: $(service_activity_summary)"
echo

if [[ "$CLEAN" == "true" ]]; then
  echo "Step 1: clean generated build artifacts"
else
  echo "Step 1: keep existing build artifacts"
fi
echo "Step 2: run build"
echo "Step 3: stop; no release is created and no services are restarted"

if [[ "$DRY_RUN" == "true" ]]; then
  echo
  echo "Dry-run only. No clean or build was performed."
  if [[ "$CLEAN" == "true" ]]; then
    echo
    "$ACM_REPO_ROOT/scripts/build/acore-clean-build.sh" --dry-run
  fi
  exit 0
fi

if [[ "$CLEAN" == "true" ]]; then
  "$ACM_REPO_ROOT/scripts/build/acore-clean-build.sh"
fi

"$ACM_REPO_ROOT/scripts/build/acore-build.sh"

echo
echo "Rebuild completed."
echo "Next explicit release steps:"
echo "  ./bin/acore-manager create-release"
echo "  ./bin/acore-manager switch-release --dry-run <release-name>"
echo "  sudo ./bin/acore-manager switch-release <release-name>"
