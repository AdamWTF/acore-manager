#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

JSON=false
doctor_output="$(mktemp)"

cleanup() {
  rm -f "$doctor_output"
}
trap cleanup EXIT

usage() {
  cat <<EOF
Usage:
  $0 [--json]
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json) JSON=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

run_check() {
  local name="$1"
  local command_path="$2"
  shift 2

  if [[ "$JSON" != "true" ]]; then
    log "$name"
  fi

  if [[ -x "$command_path" ]]; then
    if "$command_path" "$@" >"$doctor_output" 2>&1; then
      status="ok"
    else
      status="warn"
    fi
  else
    status="missing"
    printf 'missing: %s\n' "$command_path" >"$doctor_output"
  fi

  if [[ "$JSON" == "true" ]]; then
    printf '  "%s": "%s"%s\n' "$name" "$status" "$json_comma"
  else
    echo "Status: $status"
    sed 's/^/  /' "$doctor_output" | tail -n 40
  fi
}

if [[ "$JSON" == "true" ]]; then
  echo "{"
  json_comma=","
  run_check "validate" "$ACM_REPO_ROOT/scripts/config/acore-validate-config.sh"
  run_check "validate_runtime" "$ACM_REPO_ROOT/scripts/config/acore-validate-runtime.sh"
  run_check "db_check" "$ACM_REPO_ROOT/scripts/db/acore-db-check.sh"
  run_check "sleep_status" "$ACM_REPO_ROOT/scripts/power/acore-sleep-status.sh"
  json_comma=""
  run_check "service_status" "$ACM_REPO_ROOT/scripts/runtime/acore-service-status.sh"
  echo "}"
  exit 0
fi

log "Acore Manager Doctor"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "ACM_ROOT: $ACM_ROOT"
echo "BACKUP_DIR: $BACKUP_DIR"

run_check "Config validation" "$ACM_REPO_ROOT/scripts/config/acore-validate-config.sh"
run_check "Runtime validation" "$ACM_REPO_ROOT/scripts/config/acore-validate-runtime.sh"
run_check "Database check" "$ACM_REPO_ROOT/scripts/db/acore-db-check.sh"
run_check "Sleep status" "$ACM_REPO_ROOT/scripts/power/acore-sleep-status.sh"
run_check "Service status" "$ACM_REPO_ROOT/scripts/runtime/acore-service-status.sh"
run_check "Recent errors" "$ACM_REPO_ROOT/scripts/logs/acore-last-errors.sh"

log "Backup freshness"
for category in config db all; do
  latest="$(find "$BACKUP_DIR/$category" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1 || true)"
  echo "$category latest: ${latest:-none}"
done

log "Disk usage"
if [[ -e "$ACM_ROOT" ]]; then
  df -h "$ACM_ROOT" 2>/dev/null || true
else
  echo "ACM_ROOT does not exist: $ACM_ROOT"
fi
