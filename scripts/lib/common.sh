#!/usr/bin/env bash
set -Eeuo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACM_REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"

ACM_DEFAULT_CONFIG="$ACM_REPO_ROOT/config/defaults/manager.conf.example"
ACM_LOCAL_CONFIG="$ACM_REPO_ROOT/config/local/manager.conf"

if [[ ! -f "$ACM_DEFAULT_CONFIG" ]]; then
  echo "Missing default config: $ACM_DEFAULT_CONFIG" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ACM_DEFAULT_CONFIG"

if [[ -f "$ACM_LOCAL_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$ACM_LOCAL_CONFIG"
fi

# SOURCE_ROOT is the parent directory for source checkouts.
SOURCE_ROOT="$ACM_ROOT/source"

# ACORE_SOURCE_DIR is the AzerothCore git checkout.
ACORE_SOURCE_DIR="$SOURCE_ROOT/azerothcore"

# MODULES_DIR lives inside the AzerothCore checkout.
MODULES_DIR="$ACORE_SOURCE_DIR/modules"

# Backwards-compatible alias for scripts that still expect SOURCE_DIR to mean
# the AzerothCore checkout. Do not use SOURCE_DIR for the parent directory.
SOURCE_DIR="$ACORE_SOURCE_DIR"

BUILD_DIR="$ACM_ROOT/build"
RELEASES_DIR="$ACM_ROOT/releases"
CURRENT_LINK="$ACM_ROOT/current"
CURRENT_DIR="$CURRENT_LINK"
SHARED_DIR="$ACM_ROOT/shared"
BACKUP_DIR="$ACM_ROOT/backups"
MODULE_CONFIG_DIR="$CONFIG_DIR/modules"
SHARED_LOG_DIR="$SHARED_DIR/logs"

log() {
  echo
  echo "================================================================"
  echo "$1"
  echo "================================================================"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

validate_current_runtime() {
  local current_target

  [[ -L "$CURRENT_LINK" ]] || die "CURRENT_LINK is not a symlink: $CURRENT_LINK
Create a release, list releases, then switch to one:
  ./bin/acore-manager create-release
  ./bin/acore-manager list-releases
  sudo ./bin/acore-manager switch-release <release-name>"

  current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
  [[ -n "$current_target" && -d "$current_target" ]] || die "CURRENT_LINK does not point to a release: $CURRENT_LINK"

  case "$current_target" in
    "$BUILD_DIR"/staging|"$BUILD_DIR"/staging/*)
      die "CURRENT_LINK points to build staging, which is not a runtime path: $current_target"
      ;;
  esac

  case "$current_target" in
    "$RELEASES_DIR"/*)
      ;;
    *)
      die "CURRENT_LINK must point under RELEASES_DIR ($RELEASES_DIR), got: $current_target"
      ;;
  esac

  [[ -x "$CURRENT_LINK/bin/authserver" ]] || die "authserver is missing or not executable: $CURRENT_LINK/bin/authserver"
  [[ -x "$CURRENT_LINK/bin/worldserver" ]] || die "worldserver is missing or not executable: $CURRENT_LINK/bin/worldserver"
}
