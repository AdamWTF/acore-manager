#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

timestamp="$(date +%Y-%m-%d-%H%M)"
backup_dir="$BACKUP_DIR/all/$timestamp"
manifest="$backup_dir/backup-manifest.txt"
config_output="$(mktemp)"
db_output="$(mktemp)"

cleanup() {
  rm -f "$config_output" "$db_output"
}
trap cleanup EXIT

extract_backup_dir() {
  awk -F': ' '/^Backup directory: / { value = $2 } END { print value }' "$1"
}

log "Creating combined backup"
mkdir -p "$backup_dir"

{
  echo "Combined backup manifest"
  echo "Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Backup directory: $backup_dir"
  echo
} > "$manifest"

echo "Running config backup"
"$ACM_REPO_ROOT/scripts/config/acore-config-backup.sh" | tee "$config_output"
config_backup_dir="$(extract_backup_dir "$config_output")"
[[ -n "$config_backup_dir" ]] || die "unable to determine config backup directory"

echo
echo "Running database backup"
"$ACM_REPO_ROOT/scripts/db/acore-db-backup.sh" | tee "$db_output"
db_backup_dir="$(extract_backup_dir "$db_output")"
[[ -n "$db_backup_dir" ]] || die "unable to determine database backup directory"

{
  echo "Component backups:"
  echo "  config: $config_backup_dir"
  echo "  database: $db_backup_dir"
} >> "$manifest"

echo
echo "Combined backup completed."
echo "Backup directory: $backup_dir"
echo "Manifest: $manifest"

