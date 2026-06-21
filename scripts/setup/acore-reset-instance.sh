#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

ACM_LOCAL_DB_CONFIG="$ACM_REPO_ROOT/config/local/db.conf"
[[ -f "$ACM_LOCAL_DB_CONFIG" ]] && source "$ACM_LOCAL_DB_CONFIG"

DRY_RUN=false
APPLY=false
RESET_BINARIES=false
RESET_CONFIGS=false
RESET_LOGS=false
RESET_DATA=false
RESET_DATABASES=false
SAFE_STOP_FIRST=false
SKIP_PRE_BACKUP=false
CONFIRM_DATA=false
CONFIRM_DATABASES=false
RECREATE_DATABASES=false

usage() {
  cat <<EOF
Usage:
  $0 --dry-run|--apply [area flags]

Area flags:
  --binaries    Remove build output, releases, and CURRENT_LINK
  --configs     Remove shared AzerothCore runtime configs
  --logs        Remove shared and manager logs
  --data        Remove shared client data; requires --i-understand-this-deletes-shared-data
  --databases   Drop configured auth/world/characters databases; requires --i-understand-this-deletes-realm-data

Options:
  --safe-stop-first                         Run safe-stop before applying if auth/world are active
  --skip-pre-backup                         Skip automatic DB backup for --databases
  --recreate-databases                      Recreate empty configured databases after dropping them
  --i-understand-this-deletes-shared-data   Required with --data --apply
  --i-understand-this-deletes-realm-data    Required with --databases --apply
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --apply) APPLY=true ;;
    --binaries) RESET_BINARIES=true ;;
    --configs) RESET_CONFIGS=true ;;
    --logs) RESET_LOGS=true ;;
    --data) RESET_DATA=true ;;
    --databases) RESET_DATABASES=true ;;
    --safe-stop-first) SAFE_STOP_FIRST=true ;;
    --skip-pre-backup) SKIP_PRE_BACKUP=true ;;
    --recreate-databases) RECREATE_DATABASES=true ;;
    --i-understand-this-deletes-shared-data) CONFIRM_DATA=true ;;
    --i-understand-this-deletes-realm-data) CONFIRM_DATABASES=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

[[ "$APPLY" != "$DRY_RUN" ]] || die "choose exactly one of --dry-run or --apply"

if [[ "$RESET_BINARIES" != "true" && "$RESET_CONFIGS" != "true" && "$RESET_LOGS" != "true" && "$RESET_DATA" != "true" && "$RESET_DATABASES" != "true" ]]; then
  usage
  die "choose at least one reset area"
fi

if [[ "$SKIP_PRE_BACKUP" == "true" && "$RESET_DATABASES" != "true" ]]; then
  die "--skip-pre-backup is only valid with --databases"
fi

if [[ "$RECREATE_DATABASES" == "true" && "$RESET_DATABASES" != "true" ]]; then
  die "--recreate-databases is only valid with --databases"
fi

if [[ "$APPLY" == "true" && "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "reset-instance --apply must be run as root"
fi

if [[ "$APPLY" == "true" && "$RESET_DATA" == "true" && "$CONFIRM_DATA" != "true" ]]; then
  die "--data --apply requires --i-understand-this-deletes-shared-data"
fi

if [[ "$APPLY" == "true" && "$RESET_DATABASES" == "true" && "$CONFIRM_DATABASES" != "true" ]]; then
  die "--databases --apply requires --i-understand-this-deletes-realm-data"
fi

if [[ "$APPLY" == "true" ]]; then
  acquire_acm_lock reset
  if [[ "$RESET_BINARIES" == "true" ]]; then
    acquire_acm_lock build
    acquire_acm_lock release
  fi
fi

validate_reset_path() {
  local path="$1"
  local label="$2"

  require_absolute_path "$path" "$label"
  path_must_not_be_dangerous "$path" "$label"
  require_not_symlink_dir "$path" "$label"

  for protected_path in "$ACORE_SOURCE_DIR" "$MODULES_DIR" "$BACKUP_DIR" "$ACM_REPO_ROOT/config/local" "$ACM_REPO_ROOT/.env"; do
    if [[ "$path" == "$protected_path" ]] || path_is_within "$path" "$protected_path" || path_is_within "$protected_path" "$path"; then
      die "$label overlaps protected path: $path vs $protected_path"
    fi
  done
}

if [[ "$RESET_BINARIES" == "true" ]]; then
  require_safe_build_dir
  validate_reset_path "$RELEASES_DIR" "RELEASES_DIR"
fi

if [[ "$RESET_CONFIGS" == "true" ]]; then
  validate_reset_path "$CONFIG_DIR" "CONFIG_DIR"
fi

if [[ "$RESET_LOGS" == "true" ]]; then
  validate_reset_path "$SHARED_LOG_DIR" "SHARED_LOG_DIR"
  validate_reset_path "$ACM_ROOT/logs" "manager logs"
fi

if [[ "$RESET_DATA" == "true" ]]; then
  validate_reset_path "$DATADIR" "DATADIR"
fi

if [[ "$APPLY" == "true" ]]; then
  require_services_inactive_or_safe_stop_first "$SAFE_STOP_FIRST"
fi

timestamp="$(date +%Y-%m-%d-%H%M)"
reset_dir="$BACKUP_DIR/reset/$timestamp"
manifest="$reset_dir/reset-manifest.txt"

record_manifest() {
  [[ "$APPLY" == "true" ]] || return 0
  mkdir -p "$reset_dir"
  {
    echo "Reset manifest"
    echo "Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Mode: apply"
    echo "Backup directory: $reset_dir"
    echo
    echo "Areas:"
    echo "  binaries: $RESET_BINARIES"
    echo "  configs: $RESET_CONFIGS"
    echo "  logs: $RESET_LOGS"
    echo "  data: $RESET_DATA"
    echo "  databases: $RESET_DATABASES"
    echo
    echo "Actions:"
  } > "$manifest"
}

append_manifest() {
  [[ "$APPLY" == "true" ]] || return 0
  echo "  $*" >> "$manifest"
}

remove_path_contents() {
  local path="$1"
  local label="$2"

  if [[ ! -e "$path" ]]; then
    echo "Skipping missing $label: $path"
    append_manifest "missing $label: $path"
    return
  fi

  echo "Removing $label contents: $path"
  append_manifest "removed contents of $label: $path"
  find "$path" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

remove_file_or_link() {
  local path="$1"
  local label="$2"

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    echo "Skipping missing $label: $path"
    append_manifest "missing $label: $path"
    return
  fi

  echo "Removing $label: $path"
  append_manifest "removed $label: $path"
  rm -f -- "$path"
}

mysql_args=("--host=${MYSQL_HOST:-127.0.0.1}" "--port=${MYSQL_PORT:-3306}" "--user=${MYSQL_USER:-}")

run_mysql_reset() {
  MYSQL_PWD="$MYSQL_PASSWORD" command mysql "${mysql_args[@]}" --batch --skip-column-names "$@"
}

quote_identifier() {
  local value="$1"
  value="${value//\`/\`\`}"
  printf '`%s`' "$value"
}

drop_database() {
  local db_name="$1"
  local quoted

  [[ -n "$db_name" ]] || die "configured database name is empty"
  quoted="$(quote_identifier "$db_name")"
  echo "Dropping database: $db_name"
  append_manifest "dropped database: $db_name"
  run_mysql_reset -e "DROP DATABASE IF EXISTS $quoted;"
  if [[ "$RECREATE_DATABASES" == "true" ]]; then
    echo "Recreating empty database: $db_name"
    append_manifest "recreated database: $db_name"
    run_mysql_reset -e "CREATE DATABASE $quoted CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  fi
}

log "Reset instance"
echo "Mode: $([[ "$APPLY" == "true" ]] && echo apply || echo dry-run)"
echo "Services active: $(service_activity_summary)"
echo
echo "Selected areas:"
echo "  binaries: $RESET_BINARIES"
echo "  configs: $RESET_CONFIGS"
echo "  logs: $RESET_LOGS"
echo "  data: $RESET_DATA"
echo "  databases: $RESET_DATABASES"
echo

if [[ "$RESET_DATABASES" == "true" ]]; then
  echo "Database warning:"
  echo "  This affects only configured databases:"
  echo "    auth: ${MYSQL_AUTH_DB:-unset}"
  echo "    world: ${MYSQL_WORLD_DB:-unset}"
  echo "    characters: ${MYSQL_CHAR_DB:-unset}"
  echo "  Playerbots or custom module tables inside those databases will be deleted."
  echo "  Separate custom module databases are not touched."
  echo
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Would reset:"
  [[ "$RESET_BINARIES" == "true" ]] && echo "  binaries: $BUILD_DIR contents, $RELEASES_DIR contents, $CURRENT_LINK symlink"
  [[ "$RESET_CONFIGS" == "true" ]] && echo "  configs: $CONFIG_DIR contents"
  [[ "$RESET_LOGS" == "true" ]] && echo "  logs: $SHARED_LOG_DIR contents and $ACM_ROOT/logs contents"
  [[ "$RESET_DATA" == "true" ]] && echo "  data: $DATADIR contents"
  [[ "$RESET_DATABASES" == "true" ]] && echo "  databases: ${MYSQL_AUTH_DB:-unset}, ${MYSQL_WORLD_DB:-unset}, ${MYSQL_CHAR_DB:-unset}"
  echo
  echo "Dry-run only. No files or databases were changed."
  exit 0
fi

record_manifest

if [[ "$RESET_CONFIGS" == "true" ]]; then
  echo "Creating config backup before config reset"
  "$ACM_REPO_ROOT/scripts/config/acore-config-backup.sh"
  remove_path_contents "$CONFIG_DIR" "shared runtime configs"
fi

if [[ "$RESET_DATABASES" == "true" ]]; then
  command -v mysql >/dev/null 2>&1 || die "mysql client is not available"
  [[ -n "${MYSQL_HOST:-}" ]] || die "MYSQL_HOST is not set"
  [[ -n "${MYSQL_PORT:-}" ]] || die "MYSQL_PORT is not set"
  [[ -n "${MYSQL_USER:-}" ]] || die "MYSQL_USER is not set"
  [[ -n "${MYSQL_PASSWORD:-}" ]] || die "MYSQL_PASSWORD is not set"
  mysql_args=("--host=$MYSQL_HOST" "--port=$MYSQL_PORT" "--user=$MYSQL_USER")

  if [[ "$SKIP_PRE_BACKUP" != "true" ]]; then
    echo "Creating database backup before database reset"
    "$ACM_REPO_ROOT/scripts/db/acore-db-backup.sh"
  fi

  drop_database "$MYSQL_AUTH_DB"
  drop_database "$MYSQL_WORLD_DB"
  drop_database "$MYSQL_CHAR_DB"
fi

if [[ "$RESET_BINARIES" == "true" ]]; then
  remove_path_contents "$BUILD_DIR" "build output"
  remove_path_contents "$RELEASES_DIR" "releases"
  remove_file_or_link "$CURRENT_LINK" "current release symlink"
fi

if [[ "$RESET_LOGS" == "true" ]]; then
  remove_path_contents "$SHARED_LOG_DIR" "shared logs"
  remove_path_contents "$ACM_ROOT/logs" "manager logs"
fi

if [[ "$RESET_DATA" == "true" ]]; then
  remove_path_contents "$DATADIR" "shared client data"
fi

echo
echo "Reset completed."
echo "Manifest: $manifest"
