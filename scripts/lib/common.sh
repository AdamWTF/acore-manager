#!/usr/bin/env bash
set -Eeuo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACORE_MANAGER_REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"

ACORE_MANAGER_DEFAULT_CONFIG="$ACORE_MANAGER_REPO_ROOT/config/defaults/docker-manager.conf.example"
ACORE_MANAGER_LOCAL_CONFIG="$ACORE_MANAGER_REPO_ROOT/config/local/docker-manager.conf"

if [[ ! -f "$ACORE_MANAGER_DEFAULT_CONFIG" ]]; then
  echo "Missing default config: $ACORE_MANAGER_DEFAULT_CONFIG" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ACORE_MANAGER_DEFAULT_CONFIG"

if [[ -f "$ACORE_MANAGER_LOCAL_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$ACORE_MANAGER_LOCAL_CONFIG"
fi

BUILD_DIR="$ACORE_MANAGER_REPO_ROOT/build"
ACORE_SOURCE_DIR="${ACORE_SOURCE_DIR:-$BUILD_DIR/azerothcore}"
COMPOSE_OUTPUT_DIR="${COMPOSE_OUTPUT_DIR:-$BUILD_DIR/docker-compose}"
COMPOSE_OVERRIDE_FILE="${COMPOSE_OVERRIDE_FILE:-$COMPOSE_OUTPUT_DIR/docker-compose.override.yml}"
COMPOSE_ENV_FILE="${COMPOSE_ENV_FILE:-$COMPOSE_OUTPUT_DIR/docker.env}"

absolute_path() {
  local path="$1"

  if [[ "$path" = /* || "$path" =~ ^[A-Za-z]:[\\/].* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$ACORE_MANAGER_REPO_ROOT/$path"
  fi
}

ACORE_SOURCE_DIR="$(absolute_path "$ACORE_SOURCE_DIR")"
COMPOSE_OUTPUT_DIR="$(absolute_path "$COMPOSE_OUTPUT_DIR")"
COMPOSE_OVERRIDE_FILE="$(absolute_path "$COMPOSE_OVERRIDE_FILE")"
COMPOSE_ENV_FILE="$(absolute_path "$COMPOSE_ENV_FILE")"
ACORE_CONFIG_DIR="$(absolute_path "$ACORE_CONFIG_DIR")"
ACORE_DATA_DIR="$(absolute_path "$ACORE_DATA_DIR")"
ACORE_LOG_DIR="$(absolute_path "$ACORE_LOG_DIR")"

MODULES_DEFAULT_FILE="$ACORE_MANAGER_REPO_ROOT/config/defaults/modules.txt.example"
MODULES_LOCAL_FILE="$ACORE_MANAGER_REPO_ROOT/config/local/modules.txt"
MODULES_FILE="$MODULES_LOCAL_FILE"
if [[ ! -f "$MODULES_FILE" ]]; then
  MODULES_FILE="$MODULES_DEFAULT_FILE"
fi

log() {
  echo
  echo "================================================================"
  echo "$1"
  echo "================================================================"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

is_truthy() {
  case "${1:-}" in
    true|TRUE|yes|YES|1|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

trim() {
  local value="${1:-}"
  value="${value//$'\r'/}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

require_cmd() {
  local name="$1"

  command -v "$name" >/dev/null 2>&1 || die "required command is missing: $name"
}

compose_base_file() {
  local configured="${COMPOSE_BASE_FILE:-}"

  if [[ -n "$configured" ]]; then
    if [[ "$configured" = /* || "$configured" =~ ^[A-Za-z]:[\\/].* ]]; then
      printf '%s\n' "$configured"
    else
      printf '%s\n' "$ACORE_MANAGER_REPO_ROOT/$configured"
    fi
    return
  fi

  local candidate
  for candidate in \
    "$ACORE_SOURCE_DIR/docker-compose.yml" \
    "$ACORE_SOURCE_DIR/docker-compose.yaml" \
    "$ACORE_SOURCE_DIR/docker/docker-compose.yml" \
    "$ACORE_SOURCE_DIR/docker/docker-compose.yaml" \
    "$ACORE_SOURCE_DIR/conf/dist/docker/docker-compose.yml" \
    "$ACORE_SOURCE_DIR/conf/dist/docker/docker-compose.yaml"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  return 1
}

compose_project_args() {
  local base_file
  base_file="$(compose_base_file)" || die "could not find an AzerothCore Docker Compose file under $ACORE_SOURCE_DIR; run './bin/acore-manager docker sync-modules' first or set COMPOSE_BASE_FILE"

  printf '%s\n' compose -p "$COMPOSE_PROJECT_NAME" -f "$base_file" -f "$COMPOSE_OVERRIDE_FILE"
}

validate_module_name() {
  local module_name="$1"

  [[ "$module_name" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid module name '$module_name'; use letters, numbers, '.', '_', or '-' only"
}

ensure_acore_source() {
  require_cmd git
  mkdir -p "$(dirname "$ACORE_SOURCE_DIR")"

  if [[ -d "$ACORE_SOURCE_DIR/.git" ]]; then
    log "Updating AzerothCore source"
    git -C "$ACORE_SOURCE_DIR" fetch origin "$ACORE_BRANCH"
    git -C "$ACORE_SOURCE_DIR" checkout "$ACORE_BRANCH"
    git -C "$ACORE_SOURCE_DIR" pull --ff-only origin "$ACORE_BRANCH"
  elif [[ -e "$ACORE_SOURCE_DIR" ]]; then
    die "AzerothCore source path exists but is not a git checkout: $ACORE_SOURCE_DIR"
  else
    log "Cloning AzerothCore source"
    git clone --branch "$ACORE_BRANCH" "$ACORE_REPO" "$ACORE_SOURCE_DIR"
  fi
}

ensure_compose_override() {
  mkdir -p "$COMPOSE_OUTPUT_DIR" "$ACORE_CONFIG_DIR" "$ACORE_DATA_DIR" "$ACORE_LOG_DIR"

  cat > "$COMPOSE_ENV_FILE" <<EOF
MYSQL_HOST=$MYSQL_HOST
MYSQL_PORT=$MYSQL_PORT
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_AUTH_DATABASE=$MYSQL_AUTH_DATABASE
MYSQL_CHARACTER_DATABASE=$MYSQL_CHARACTER_DATABASE
MYSQL_WORLD_DATABASE=$MYSQL_WORLD_DATABASE
EOF

  cat > "$COMPOSE_OVERRIDE_FILE" <<EOF
services:
  $SERVICE_DATABASE:
    profiles:
      - local-db
    volumes:
      - "$ACORE_DATA_DIR/mysql:/var/lib/mysql"

  $SERVICE_DB_IMPORT:
    env_file:
      - "$COMPOSE_ENV_FILE"
    volumes:
      - "$ACORE_CONFIG_DIR:/azerothcore/env/dist/etc"
      - "$ACORE_DATA_DIR:/azerothcore/env/dist/data"
      - "$ACORE_LOG_DIR:/azerothcore/env/dist/logs"

  $SERVICE_AUTHSERVER:
    env_file:
      - "$COMPOSE_ENV_FILE"
    volumes:
      - "$ACORE_CONFIG_DIR:/azerothcore/env/dist/etc"
      - "$ACORE_DATA_DIR:/azerothcore/env/dist/data"
      - "$ACORE_LOG_DIR:/azerothcore/env/dist/logs"

  $SERVICE_WORLDSERVER:
    env_file:
      - "$COMPOSE_ENV_FILE"
    volumes:
      - "$ACORE_CONFIG_DIR:/azerothcore/env/dist/etc"
      - "$ACORE_DATA_DIR:/azerothcore/env/dist/data"
      - "$ACORE_LOG_DIR:/azerothcore/env/dist/logs"
EOF
}
