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
database=""
sql_file=""

usage() {
  cat <<EOF
Usage:
  $0 <sql-file> --database auth|world|characters --dry-run
  $0 <sql-file> --database auth|world|characters --apply [--skip-pre-backup]
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
      if [[ -z "$sql_file" ]]; then
        sql_file="$1"
      else
        die "unknown argument: $1"
      fi
      ;;
  esac
  shift
done

[[ -f "$sql_file" ]] || die "SQL file is required and must exist: ${sql_file:-}"
[[ "$APPLY" != "$DRY_RUN" ]] || die "choose exactly one of --dry-run or --apply"

case "$database" in
  auth) db_name="$MYSQL_AUTH_DB" ;;
  world) db_name="$MYSQL_WORLD_DB" ;;
  characters) db_name="$MYSQL_CHAR_DB" ;;
  *) die "--database must be one of: auth, world, characters" ;;
esac

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Would import $sql_file into $database database ($db_name)"
  exit 0
fi

command -v mysql >/dev/null 2>&1 || die "mysql client is not available"
[[ -n "${MYSQL_HOST:-}" ]] || die "MYSQL_HOST is not set"
[[ -n "${MYSQL_PORT:-}" ]] || die "MYSQL_PORT is not set"
[[ -n "${MYSQL_USER:-}" ]] || die "MYSQL_USER is not set"
[[ -n "${MYSQL_PASSWORD:-}" ]] || die "MYSQL_PASSWORD is not set"

if [[ "$SKIP_PRE_BACKUP" != "true" ]]; then
  "$ACM_REPO_ROOT/scripts/db/acore-db-backup.sh"
fi

echo "Importing $sql_file into $database database ($db_name)"
MYSQL_PWD="$MYSQL_PASSWORD" command mysql \
  "--host=$MYSQL_HOST" \
  "--port=$MYSQL_PORT" \
  "--user=$MYSQL_USER" \
  "$db_name" < "$sql_file"
