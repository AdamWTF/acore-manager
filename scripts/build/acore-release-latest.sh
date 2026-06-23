#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

CLEAN=false

usage() {
  cat <<EOF
Usage:
  $0 [--clean]

Runs validate, DB check, source/module update, build, release creation,
config preparation, config backup, release switch, and final status.

Options:
  --clean  Remove generated build artifacts before building.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --clean)
      CLEAN=true
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

acquire_acm_lock build
acquire_acm_lock release
export_acm_lock_held build
export_acm_lock_held release

release_name=""
release_path=""
release_output_file="$(mktemp)"

cleanup() {
  rm -f "$release_output_file"
}
trap cleanup EXIT

required_script() {
  local script_path="$1"

  [[ -x "$script_path" ]] || die "required script is missing or not executable: $script_path"
}

run_step() {
  local title="$1"
  local script_path="$2"
  shift 2

  required_script "$script_path"
  log "$title"
  "$script_path" "$@"
}

log "Starting full update/build/release workflow"

run_step "Validating config" "$ACM_REPO_ROOT/scripts/config/acore-validate-config.sh"
run_step "Checking database" "$ACM_REPO_ROOT/scripts/db/acore-db-check.sh"
run_step "Updating AzerothCore source" "$ACM_REPO_ROOT/scripts/source/acore-update-source.sh"
run_step "Updating AzerothCore modules" "$ACM_REPO_ROOT/scripts/source/acore-update-modules.sh"
if [[ "$CLEAN" == "true" ]]; then
  run_step "Cleaning generated build artifacts" "$ACM_REPO_ROOT/scripts/build/acore-clean-build.sh"
fi
run_step "Building AzerothCore" "$ACM_REPO_ROOT/scripts/build/acore-build.sh"

required_script "$ACM_REPO_ROOT/scripts/build/acore-create-release.sh"
log "Creating release"
"$ACM_REPO_ROOT/scripts/build/acore-create-release.sh" | tee "$release_output_file"

release_name="$(awk -F': ' '/^Release name: / { value = $2 } END { print value }' "$release_output_file")"
release_path="$(awk -F': ' '/^Release path: / { value = $2 } END { print value }' "$release_output_file")"

[[ -n "$release_name" ]] || die "unable to determine release name from acore-create-release.sh output"
[[ -n "$release_path" ]] || die "unable to determine release path from acore-create-release.sh output"
[[ -d "$release_path" ]] || die "created release path does not exist: $release_path"

prepare_configs_script="$ACM_REPO_ROOT/scripts/config/acore-prepare-configs.sh"
if [[ -x "$prepare_configs_script" ]]; then
  run_step "Preparing shared configs" "$prepare_configs_script" "$release_name"
else
  log "Skipping shared config preparation"
  echo "Optional script not found or not executable: $prepare_configs_script"
fi

config_backup_script="$ACM_REPO_ROOT/scripts/config/acore-config-backup.sh"
if [[ -x "$config_backup_script" ]]; then
  run_step "Backing up config" "$config_backup_script"
else
  log "Skipping config backup"
  echo "Optional script not found or not executable: $config_backup_script"
fi

run_step "Switching active release" "$ACM_REPO_ROOT/scripts/releases/acore-switch-release.sh" "$release_name"
run_step "Checking runtime status" "$ACM_REPO_ROOT/scripts/runtime/acore-status.sh"

log "Release workflow complete"
echo "Release name: $release_name"
echo "Release path: $release_path"
echo "Current link: $CURRENT_LINK"
