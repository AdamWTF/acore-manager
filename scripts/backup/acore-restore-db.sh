#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

ACM_LOCAL_DB_CONFIG="$ACM_REPO_ROOT/config/local/db.conf"
[[ -f "$ACM_LOCAL_DB_CONFIG" ]] && source "$ACM_LOCAL_DB_CONFIG"

APPLY=false
DRY_RUN=false
SKIP_PRE_BACKUP=false
backup_path=""
database=""

usage() {
  cat <<EOF
Usage:
  $0 <backup-path> --database auth|world|characters|all --dry-run
  $0 <backup-path> --database auth|world|characters|all --apply [--skip-pre-backup]
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --database) database="${2:-}"; shift ;;
    --dry-run) DRY_RUN=true ;;
    --apply) APPLY=true ;;
    --skip-pre-backup) SKIP_PRE_BACKUP=true ;;
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
[[ -d "$backup_path" ]] || die "backup path does not exist: $backup_path"
[[ "$APPLY" != "$DRY_RUN" ]] || die "choose exactly one of --dry-run or --apply"

db_name_for_label() {
  case "$1" in
    auth) echo "$MYSQL_AUTH_DB" ;;
    world) echo "$MYSQL_WORLD_DB" ;;
    characters) echo "$MYSQL_CHAR_DB" ;;
    *) return 1 ;;
  esac
}

sql_file_for_db() {
  local db_name="$1"

  find "$backup_path" -type f -name "$db_name.sql" | sort | head -n 1
}

labels=()
case "$database" in
  auth|world|characters) labels=("$database") ;;
  all) labels=(auth world characters) ;;
  *) die "--database must be one of: auth, world, characters, all" ;;
esac

if [[ "$APPLY" == "true" ]]; then
  command -v mysql >/dev/null 2>&1 || die "mysql client is not available"
  [[ -n "${MYSQL_HOST:-}" ]] || die "MYSQL_HOST is not set"
  [[ -n "${MYSQL_PORT:-}" ]] || die "MYSQL_PORT is not set"
  [[ -n "${MYSQL_USER:-}" ]] || die "MYSQL_USER is not set"
  [[ -n "${MYSQL_PASSWORD:-}" ]] || die "MYSQL_PASSWORD is not set"

  mysql_args=("--host=$MYSQL_HOST" "--port=$MYSQL_PORT" "--user=$MYSQL_USER")

  run_mysql_file() {
    local db_name="$1"
    local sql_file="$2"

    MYSQL_PWD="$MYSQL_PASSWORD" command mysql "${mysql_args[@]}" "$db_name" < "$sql_file"
  }

  if [[ "$SKIP_PRE_BACKUP" != "true" ]]; then
    "$ACM_REPO_ROOT/scripts/db/acore-db-backup.sh"
  fi
fi

for label in "${labels[@]}"; do
  db_name="$(db_name_for_label "$label")"
  sql_file="$(sql_file_for_db "$db_name")"
  [[ -n "$sql_file" ]] || die "SQL dump not found for $label database ($db_name) under $backup_path"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would restore $label database ($db_name) from $sql_file"
  else
    echo "Restoring $label database ($db_name) from $sql_file"
    run_mysql_file "$db_name" "$sql_file"
  fi
done
