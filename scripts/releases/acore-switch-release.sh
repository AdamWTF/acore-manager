#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

DRY_RUN=false
release_name=""

usage() {
  cat <<EOF
Usage:
  $0 [--dry-run] <release-name>
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
      if [[ -z "$release_name" ]]; then
        release_name="$1"
      else
        die "unknown argument: $1"
      fi
      ;;
  esac
  shift
done

[[ -n "$release_name" ]] || die "usage: $0 <release-name>"
[[ "$release_name" != *"/"* ]] || die "release name must not contain slashes: $release_name"

release_dir="$RELEASES_DIR/$release_name"
[[ -d "$release_dir" ]] || die "release does not exist: $release_dir"
[[ -x "$release_dir/bin/authserver" ]] || die "authserver is not executable in release: $release_dir/bin/authserver"
[[ -x "$release_dir/bin/worldserver" ]] || die "worldserver is not executable in release: $release_dir/bin/worldserver"

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry-run release switch"
  echo "Release: $release_name"
  echo "Path: $release_dir"
  echo "Would stop world service: $WORLD_SERVICE"
  echo "Would stop auth service: $AUTH_SERVICE"
  echo "Would update current link: $CURRENT_LINK -> $release_dir"
  echo "Would link shared configs into the selected release"
  echo "Would start auth service: $AUTH_SERVICE"
  echo "Would start world service: $WORLD_SERVICE"
  if command -v systemctl >/dev/null 2>&1; then
    validate_systemd_runtime_paths
  else
    echo "WARN: systemctl is not available; skipped systemd unit validation"
  fi
  "$ACM_REPO_ROOT/scripts/config/acore-check-data.sh" || true
  exit 0
fi

command -v systemctl >/dev/null 2>&1 || die "systemctl is not available"
validate_systemd_runtime_paths

previous_target=""
if [[ -L "$CURRENT_LINK" ]]; then
  previous_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
fi

link_configs_script="$ACM_REPO_ROOT/scripts/config/acore-link-shared-configs.sh"
[[ -x "$link_configs_script" ]] || die "shared config linker is not executable: $link_configs_script"

rollback_to_previous_release() {
  local reason="$1"
  local rollback_failed=false

  log "Rolling back failed release switch"
  echo "Reason: $reason"

  if [[ -z "$previous_target" || ! -d "$previous_target" ]]; then
    echo "ERROR: no previous release target is available; manual recovery is required."
    echo "Current link: $CURRENT_LINK"
    return 1
  fi

  echo "Stopping services before rollback"
  systemctl stop "$WORLD_SERVICE" || rollback_failed=true
  systemctl stop "$AUTH_SERVICE" || rollback_failed=true

  echo "Restoring current link: $CURRENT_LINK -> $previous_target"
  ln -sfn "$previous_target" "$CURRENT_LINK" || rollback_failed=true

  if [[ "$rollback_failed" != "true" ]]; then
    echo "Relinking shared configs for previous release"
    "$link_configs_script" || rollback_failed=true
  fi

  echo "Attempting to restart previous auth service: $AUTH_SERVICE"
  systemctl start "$AUTH_SERVICE" || rollback_failed=true

  echo "Attempting to restart previous world service: $WORLD_SERVICE"
  systemctl start "$WORLD_SERVICE" || rollback_failed=true

  if [[ "$rollback_failed" == "true" ]]; then
    echo "ERROR: rollback attempt did not complete cleanly; inspect services and $CURRENT_LINK manually."
    return 1
  fi

  echo "Rollback complete. Previous release is active again."
  return 0
}

fail_and_rollback() {
  local reason="$1"

  rollback_to_previous_release "$reason" || true
  die "$reason"
}

validate_switched_runtime() {
  local current_target

  [[ -L "$CURRENT_LINK" ]] || {
    echo "ERROR: CURRENT_LINK is not a symlink: $CURRENT_LINK"
    return 1
  }

  current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
  [[ -n "$current_target" && -d "$current_target" ]] || {
    echo "ERROR: CURRENT_LINK does not point to a release: $CURRENT_LINK"
    return 1
  }

  case "$current_target" in
    "$RELEASES_DIR"/*)
      ;;
    *)
      echo "ERROR: CURRENT_LINK must point under RELEASES_DIR ($RELEASES_DIR), got: $current_target"
      return 1
      ;;
  esac

  [[ -x "$CURRENT_LINK/bin/authserver" ]] || {
    echo "ERROR: authserver is missing or not executable: $CURRENT_LINK/bin/authserver"
    return 1
  }

  [[ -x "$CURRENT_LINK/bin/worldserver" ]] || {
    echo "ERROR: worldserver is missing or not executable: $CURRENT_LINK/bin/worldserver"
    return 1
  }
}

log "Switching active release"
echo "Release: $release_name"
echo "Path: $release_dir"
echo "Previous release: ${previous_target:-none}"
sleep_thaw_if_enabled

echo "Stopping world service: $WORLD_SERVICE"
systemctl stop "$WORLD_SERVICE" || die "failed to stop world service: $WORLD_SERVICE"

echo "Stopping auth service: $AUTH_SERVICE"
systemctl stop "$AUTH_SERVICE" || die "failed to stop auth service: $AUTH_SERVICE"

mkdir -p "$(dirname "$CURRENT_LINK")"
ln -sfn "$release_dir" "$CURRENT_LINK"
echo "Updated current link: $CURRENT_LINK -> $release_dir"

validate_switched_runtime || fail_and_rollback "new release failed runtime validation: $release_dir"
"$link_configs_script" || fail_and_rollback "failed to link shared configs for new release: $release_dir"

echo "Active runtime path: $CURRENT_LINK"

echo "Starting auth service: $AUTH_SERVICE"
systemctl start "$AUTH_SERVICE" || fail_and_rollback "failed to start auth service: $AUTH_SERVICE"

echo "Starting world service: $WORLD_SERVICE"
systemctl start "$WORLD_SERVICE" || fail_and_rollback "failed to start world service: $WORLD_SERVICE"

status_script="$ACM_REPO_ROOT/scripts/runtime/acore-status.sh"
if [[ -x "$status_script" ]]; then
  "$status_script"
else
  echo "Status script is not executable or not found: $status_script"
fi
