#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

ACM_LOCAL_DB_CONFIG="$ACM_REPO_ROOT/config/local/db.conf"
[[ -f "$ACM_LOCAL_DB_CONFIG" ]] && source "$ACM_LOCAL_DB_CONFIG"

APPLY=false
DRY_RUN=false

usage() {
  cat <<EOF
Usage:
  $0 --dry-run
  $0 --apply

Creates configured auth/world/characters databases if they are missing.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --apply) APPLY=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

[[ "$APPLY" != "$DRY_RUN" ]] || die "choose exactly one of --dry-run or --apply"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Would ensure databases exist:"
  echo "  auth: ${MYSQL_AUTH_DB:-unset}"
  echo "  world: ${MYSQL_WORLD_DB:-unset}"
  echo "  characters: ${MYSQL_CHAR_DB:-unset}"
  echo "No MySQL connection was attempted in dry-run mode."
  exit 0
fi

command -v mysql >/dev/null 2>&1 || die "mysql client is not available"
[[ -n "${MYSQL_HOST:-}" ]] || die "MYSQL_HOST is not set"
[[ -n "${MYSQL_PORT:-}" ]] || die "MYSQL_PORT is not set"
[[ -n "${MYSQL_USER:-}" ]] || die "MYSQL_USER is not set"
[[ -n "${MYSQL_PASSWORD:-}" ]] || die "MYSQL_PASSWORD is not set"

mysql_args=("--host=$MYSQL_HOST" "--port=$MYSQL_PORT" "--user=$MYSQL_USER" "--batch" "--skip-column-names")

run_mysql() {
  MYSQL_PWD="$MYSQL_PASSWORD" command mysql "${mysql_args[@]}" "$@"
}

database_exists() {
  local db_name="$1"
  local count

  count="$(run_mysql -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${db_name}';" 2>/dev/null || true)"
  [[ "$count" == "1" ]]
}

for db_name in "$MYSQL_AUTH_DB" "$MYSQL_WORLD_DB" "$MYSQL_CHAR_DB"; do
  [[ -n "$db_name" ]] || die "configured database name is empty"
  if database_exists "$db_name"; then
    echo "Exists: $db_name"
  else
    echo "Creating database: $db_name"
    run_mysql -e "CREATE DATABASE \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  fi
done
