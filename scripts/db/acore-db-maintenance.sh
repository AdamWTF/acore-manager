#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

ACM_LOCAL_DB_CONFIG="$ACM_REPO_ROOT/config/local/db.conf"
[[ -f "$ACM_LOCAL_DB_CONFIG" ]] && source "$ACM_LOCAL_DB_CONFIG"

usage() {
  cat <<EOF
Usage:
  $0

Runs read-only database maintenance checks and prints recommended mysqlcheck
commands. No repair, optimize, or data-changing command is run.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    die "unknown argument: $1"
    ;;
esac

command -v mysql >/dev/null 2>&1 || die "mysql client is not available"
[[ -n "${MYSQL_HOST:-}" ]] || die "MYSQL_HOST is not set"
[[ -n "${MYSQL_PORT:-}" ]] || die "MYSQL_PORT is not set"
[[ -n "${MYSQL_USER:-}" ]] || die "MYSQL_USER is not set"
[[ -n "${MYSQL_PASSWORD:-}" ]] || die "MYSQL_PASSWORD is not set"

mysql_args=("--host=$MYSQL_HOST" "--port=$MYSQL_PORT" "--user=$MYSQL_USER" "--batch")

run_mysql() {
  MYSQL_PWD="$MYSQL_PASSWORD" command mysql "${mysql_args[@]}" "$@"
}

log "Database maintenance status"
for db_name in "$MYSQL_AUTH_DB" "$MYSQL_WORLD_DB" "$MYSQL_CHAR_DB"; do
  [[ -n "$db_name" ]] || continue
  echo
  echo "Database: $db_name"
  run_mysql -e "SELECT TABLE_SCHEMA, COUNT(*) AS tables_count, ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 1) AS size_mb FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '${db_name}' GROUP BY TABLE_SCHEMA;" || true
  echo "Recommended manual checks:"
  echo "  mysqlcheck --check --databases $db_name"
  echo "  mysqlcheck --analyze --databases $db_name"
done

echo
echo "No repair, optimize, or data-changing command was run."
