#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

errors=0

require_var() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    echo "ERROR: $name is not set"
    errors=$((errors + 1))
  else
    echo "OK: $name is set"
  fi
}

check_cmd() {
  local name="$1"

  if command -v "$name" >/dev/null 2>&1; then
    echo "OK: command found: $name"
  else
    echo "ERROR: command missing: $name"
    errors=$((errors + 1))
  fi
}

validate_modules_file() {
  local module_name module_url module_branch line_number=0

  [[ -f "$MODULES_FILE" ]] || die "modules file is missing: $MODULES_FILE"
  echo "OK: modules file found: $MODULES_FILE"

  while IFS='|' read -r module_name module_url module_branch || [[ -n "${module_name:-}" ]]; do
    line_number=$((line_number + 1))
    module_name="$(trim "${module_name:-}")"
    module_url="$(trim "${module_url:-}")"
    module_branch="$(trim "${module_branch:-}")"

    [[ -z "$module_name" ]] && continue
    [[ "$module_name" =~ ^# ]] && continue

    if [[ -z "$module_url" || -z "$module_branch" ]]; then
      echo "ERROR: invalid module line $line_number; expected module-name|git-url|branch"
      errors=$((errors + 1))
    elif [[ ! "$module_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo "ERROR: invalid module name on line $line_number: $module_name"
      errors=$((errors + 1))
    else
      echo "OK: module configured: $module_name"
    fi
  done < "$MODULES_FILE"
}

log "Required Variables"
for name in \
  ACORE_REPO \
  ACORE_BRANCH \
  ACORE_SOURCE_DIR \
  COMPOSE_PROJECT_NAME \
  SERVICE_DATABASE \
  SERVICE_DB_IMPORT \
  SERVICE_AUTHSERVER \
  SERVICE_WORLDSERVER \
  ACORE_CONFIG_DIR \
  ACORE_DATA_DIR \
  ACORE_LOG_DIR; do
  require_var "$name"
done

log "Required Commands"
check_cmd git
check_cmd docker
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    echo "OK: docker compose is available"
  else
    echo "ERROR: docker compose is not available"
    errors=$((errors + 1))
  fi
fi

log "Paths"
echo "AzerothCore source: $ACORE_SOURCE_DIR"
echo "Compose override:   $COMPOSE_OVERRIDE_FILE"
echo "Config directory:   $ACORE_CONFIG_DIR"
echo "Data directory:     $ACORE_DATA_DIR"
echo "Log directory:      $ACORE_LOG_DIR"
if [[ -d "$ACORE_SOURCE_DIR" ]]; then
  if compose_base_file >/dev/null 2>&1; then
    echo "OK: Compose base file: $(compose_base_file)"
  else
    echo "WARN: no Compose base file found yet; run sync-modules to clone AzerothCore"
  fi
else
  echo "WARN: AzerothCore source has not been cloned yet"
fi

log "Modules"
validate_modules_file

log "Database Mode"
if is_truthy "$MYSQL_EXTERNAL"; then
  echo "OK: external MySQL host configured: $MYSQL_HOST:$MYSQL_PORT"
else
  echo "OK: local Compose database service configured: $SERVICE_DATABASE"
fi

if [[ "$errors" -gt 0 ]]; then
  die "Docker manager validation failed with $errors error(s)"
fi

echo
echo "Docker manager validation completed with no blocking errors."
