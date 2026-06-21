#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

FORCE=false
BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_BACKUP_DIR="$BACKUP_DIR/systemd/$BACKUP_STAMP"
changed_units=()
runtime_units_changed=false

usage() {
  cat <<EOF
Usage:
  $0 [--force]

Installs or updates acore-manager systemd unit files.

Options:
  --force  Replace existing managed units after backing them up.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
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

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "install-services must be run as root, for example: sudo $0"
  fi
}

unit_known_to_systemd() {
  local service="$1"

  systemd_available || return 1
  systemctl list-unit-files "$service" --no-legend 2>/dev/null | awk -v service="$service" '$1 == service { found = 1 } END { exit !found }'
}

backup_existing_unit() {
  local dest_file="$1"
  local service_name="$2"

  [[ -f "$dest_file" ]] || return 0

  mkdir -p "$SERVICE_BACKUP_DIR"
  cp -a "$dest_file" "$SERVICE_BACKUP_DIR/$service_name"
  echo "Backed up existing unit: $dest_file -> $SERVICE_BACKUP_DIR/$service_name"
}

install_service_template() {
  local source_file="$1"
  local service_name="$2"
  local restart_warning="${3:-false}"
  local dest_file="$SYSTEMD_DIR/$service_name"

  if [[ ! -f "$source_file" ]]; then
    echo "WARN: service template missing: $source_file"
    return
  fi

  if [[ -e "$dest_file" && "$FORCE" != "true" ]]; then
    echo "Leaving existing service unchanged: $dest_file"
    echo "Use --force to back it up and replace it from $source_file"
    return
  fi

  if [[ ! -e "$dest_file" && "$FORCE" != "true" ]] && unit_known_to_systemd "$service_name"; then
    echo "WARN: $service_name is known to systemd but no file exists at $dest_file"
    echo "      Review with: systemctl cat $service_name"
  fi

  backup_existing_unit "$dest_file" "$service_name"
  echo "Installing service template: $source_file -> $dest_file"
  install -m 0644 "$source_file" "$dest_file"
  changed_units+=("$service_name")

  if [[ "$restart_warning" == "true" ]]; then
    runtime_units_changed=true
  fi
}

enable_shutdown_hook() {
  local service="acore-manager-shutdown.service"

  if ! systemd_available; then
    echo "WARN: systemctl is not available; skipped enable/start for $service"
    return
  fi

  if [[ ! -f "$SYSTEMD_DIR/$service" ]]; then
    echo "WARN: shutdown hook unit is not installed: $SYSTEMD_DIR/$service"
    return
  fi

  echo "Enabling shutdown hook: $service"
  systemctl enable "$service"
  echo "Starting shutdown hook: $service"
  systemctl start "$service"
}

require_root

log "Installing acore-manager systemd services"
install -d -m 0755 "$SYSTEMD_DIR"

install_service_template \
  "$ACM_REPO_ROOT/systemd/azerothcore-auth.service" \
  "$AUTH_SERVICE" \
  true

install_service_template \
  "$ACM_REPO_ROOT/systemd/azerothcore-world.service" \
  "$WORLD_SERVICE" \
  true

install_service_template \
  "$ACM_REPO_ROOT/systemd/acore-sleep-monitor.service" \
  "acore-sleep-monitor.service"

install_service_template \
  "$ACM_REPO_ROOT/systemd/acore-sleep-proxy.service" \
  "acore-sleep-proxy.service"

install_service_template \
  "$ACM_REPO_ROOT/systemd/acore-manager-shutdown.service" \
  "acore-manager-shutdown.service"

if systemd_available; then
  echo "Reloading systemd units"
  systemctl daemon-reload
else
  echo "WARN: systemctl is not available; skipped daemon-reload"
fi

enable_shutdown_hook

echo
if [[ "${#changed_units[@]}" -gt 0 ]]; then
  echo "Installed or updated units:"
  printf '  %s\n' "${changed_units[@]}"
else
  echo "No unit files were changed."
fi

if [[ -d "$SERVICE_BACKUP_DIR" ]]; then
  echo "Unit backups: $SERVICE_BACKUP_DIR"
fi

if [[ "$runtime_units_changed" == "true" ]]; then
  echo
  echo "WARN: auth/world service templates changed. Live services were not restarted."
  echo "      Restart them explicitly during a maintenance window if the new unit settings should take effect now."
fi
