#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

timestamp="$(date +%Y-%m-%d-%H%M)"
backup_dir="$BACKUP_DIR/config/$timestamp"
manifest="$backup_dir/backup-manifest.txt"

copy_dir_if_present() {
  local source_dir="$1"
  local dest_name="$2"

  if [[ -d "$source_dir" ]]; then
    echo "Backing up $source_dir"
    mkdir -p "$backup_dir/$dest_name"
    cp -a "$source_dir/." "$backup_dir/$dest_name/"
    echo "  $source_dir -> $backup_dir/$dest_name" >> "$manifest"
  else
    echo "WARN: optional path missing: $source_dir"
    echo "  WARN missing: $source_dir" >> "$manifest"
  fi
}

copy_file_if_present() {
  local source_file="$1"
  local dest_dir="$2"

  if [[ -f "$source_file" ]]; then
    echo "Backing up $source_file"
    mkdir -p "$backup_dir/$dest_dir"
    cp -a "$source_file" "$backup_dir/$dest_dir/"
    echo "  $source_file -> $backup_dir/$dest_dir/" >> "$manifest"
  else
    echo "WARN: optional file missing: $source_file"
    echo "  WARN missing: $source_file" >> "$manifest"
  fi
}

log "Creating config backup"
mkdir -p "$backup_dir"

{
  echo "Config backup manifest"
  echo "Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Backup directory: $backup_dir"
  echo
  echo "Copied paths:"
} > "$manifest"

copy_dir_if_present "$CONFIG_DIR" "shared-configs"
copy_dir_if_present "$ACM_REPO_ROOT/config/local" "manager-local"

copy_file_if_present "/etc/systemd/system/$AUTH_SERVICE" "systemd"
copy_file_if_present "/etc/systemd/system/$WORLD_SERVICE" "systemd"
copy_file_if_present "/etc/systemd/system/acore-sleep-proxy.service" "systemd"
copy_file_if_present "/etc/systemd/system/acore-sleep-monitor.service" "systemd"
copy_file_if_present "/etc/systemd/system/acore-manager-shutdown.service" "systemd"
copy_file_if_present "/etc/cron.d/acore-manager-restart" "cron"

echo
echo "Config backup completed."
echo "Backup directory: $backup_dir"
echo "Manifest: $manifest"
