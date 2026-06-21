#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

list_category() {
  local category="$1"
  local dir="$BACKUP_DIR/$category"
  local backup manifest

  log "$category backups"
  if [[ ! -d "$dir" ]]; then
    echo "none found: $dir"
    return
  fi

  while IFS= read -r backup; do
    manifest="$backup/backup-manifest.txt"
    if [[ -f "$manifest" ]]; then
      echo "$(basename "$backup")  manifest=$manifest"
    else
      echo "$(basename "$backup")  manifest=missing"
    fi
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d | sort -r)
}

list_category "all"
list_category "config"
list_category "db"
list_category "systemd"
list_category "cron"

