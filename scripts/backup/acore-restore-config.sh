#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

APPLY=false
DRY_RUN=false
backup_path=""

usage() {
  cat <<EOF
Usage:
  $0 <backup-path> --dry-run
  $0 <backup-path> --apply

Restores shared configs, config/local, managed systemd units, and restart cron
from a config backup directory.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --apply) APPLY=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ -z "$backup_path" ]]; then
        backup_path="$1"
      else
        die "unknown argument: $1"
      fi
      ;;
  esac
  shift
done

[[ -n "$backup_path" ]] || die "backup path is required"
[[ "$APPLY" != "$DRY_RUN" ]] || die "choose exactly one of --dry-run or --apply"
[[ -d "$backup_path" ]] || die "backup path does not exist: $backup_path"

restore_dir() {
  local source_dir="$1"
  local dest_dir="$2"

  if [[ ! -d "$source_dir" ]]; then
    echo "Skipping missing backup directory: $source_dir"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would restore directory: $source_dir -> $dest_dir"
  else
    mkdir -p "$dest_dir"
    cp -a "$source_dir/." "$dest_dir/"
    echo "Restored directory: $source_dir -> $dest_dir"
  fi
}

restore_files() {
  local source_dir="$1"
  local dest_dir="$2"
  local file

  if [[ ! -d "$source_dir" ]]; then
    echo "Skipping missing backup directory: $source_dir"
    return
  fi

  if [[ "$APPLY" == "true" ]]; then
    mkdir -p "$dest_dir"
  fi

  while IFS= read -r file; do
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "Would restore file: $file -> $dest_dir/$(basename "$file")"
    else
      cp -a "$file" "$dest_dir/"
      echo "Restored file: $file -> $dest_dir/$(basename "$file")"
    fi
  done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type f | sort)
}

if [[ "$APPLY" == "true" && "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "restore-config --apply must be run as root"
fi

log "Restoring config backup"
echo "Backup path: $backup_path"
echo "Mode: $([[ "$APPLY" == "true" ]] && echo apply || echo dry-run)"

restore_dir "$backup_path/shared-configs" "$CONFIG_DIR"
restore_dir "$backup_path/manager-local" "$ACM_REPO_ROOT/config/local"
restore_files "$backup_path/systemd" "/etc/systemd/system"
restore_files "$backup_path/cron" "/etc/cron.d"

if [[ "$APPLY" == "true" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  echo "Reloaded systemd."
fi

