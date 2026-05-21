#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

APPLY=false

usage() {
  cat <<EOF
Usage:
  $0 [--apply]

Checks installed systemd units for build/staging runtime paths. With --apply,
reinstalls acore-manager service templates that run /opt/acore-manager/current.
This script reloads systemd after changes but does not restart services.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "checking and fixing installed systemd units requires root: sudo $0"
fi

auth_unit="/etc/systemd/system/$AUTH_SERVICE"
world_unit="/etc/systemd/system/$WORLD_SERVICE"
found_problem=false

inspect_unit() {
  local unit_file="$1"
  local template_file="$2"

  if [[ ! -f "$unit_file" ]]; then
    echo "WARN: installed unit missing: $unit_file"
    return
  fi

  if grep -q 'build/staging' "$unit_file"; then
    found_problem=true
    echo "ERROR: unit references build/staging: $unit_file"
    grep -n 'build/staging' "$unit_file" || true

    if [[ "$APPLY" == "true" ]]; then
      backup_file="$unit_file.$(date +%Y%m%d-%H%M%S).bak"
      cp -a "$unit_file" "$backup_file"
      install -m 0644 "$template_file" "$unit_file"
      echo "Backed up old unit: $backup_file"
      echo "Installed template: $template_file -> $unit_file"
    else
      echo "Run with --apply to install the current-based template."
    fi
  else
    echo "OK: no build/staging reference in $unit_file"
  fi
}

log "Checking runtime systemd paths"
inspect_unit "$auth_unit" "$ACM_REPO_ROOT/systemd/azerothcore-auth.service"
inspect_unit "$world_unit" "$ACM_REPO_ROOT/systemd/azerothcore-world.service"

if [[ "$APPLY" == "true" ]]; then
  systemctl daemon-reload
  echo "Reloaded systemd. Services were not restarted."
elif [[ "$found_problem" == "true" ]]; then
  echo
  echo "Detected staging runtime paths. To fix:"
  echo "  sudo $0 --apply"
fi
