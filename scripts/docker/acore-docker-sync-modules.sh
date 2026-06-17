#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

ensure_acore_source

modules_dir="$ACORE_SOURCE_DIR/modules"
mkdir -p "$modules_dir"

log "Syncing AzerothCore modules"

synced=0
while IFS='|' read -r module_name module_url module_branch || [[ -n "${module_name:-}" ]]; do
  module_name="$(trim "${module_name:-}")"
  module_url="$(trim "${module_url:-}")"
  module_branch="$(trim "${module_branch:-}")"

  [[ -z "$module_name" ]] && continue
  [[ "$module_name" =~ ^# ]] && continue

  [[ -n "$module_url" && -n "$module_branch" ]] || die "invalid module line for '$module_name'; expected module-name|git-url|branch"
  validate_module_name "$module_name"

  module_path="$modules_dir/$module_name"
  if [[ -d "$module_path/.git" ]]; then
    echo "Updating module: $module_name"
    git -C "$module_path" remote set-url origin "$module_url"
    git -C "$module_path" fetch origin "$module_branch"
    git -C "$module_path" checkout "$module_branch"
    git -C "$module_path" pull --ff-only origin "$module_branch"
  elif [[ -e "$module_path" ]]; then
    die "module path exists but is not a git checkout: $module_path"
  else
    echo "Cloning module: $module_name"
    git clone --branch "$module_branch" "$module_url" "$module_path"
  fi

  synced=$((synced + 1))
done < "$MODULES_FILE"

if [[ "$synced" -eq 0 ]]; then
  echo "No modules configured in $MODULES_FILE"
else
  echo "Synced $synced module(s) into $modules_dir"
fi

ensure_compose_override
echo "Compose override written: $COMPOSE_OVERRIDE_FILE"
