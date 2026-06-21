#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

FORCE=false
PRINT_AUTO_RESTART_CRON=false
BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"
SYSTEMD_DIR="/etc/systemd/system"
CRON_DIR="/etc/cron.d"
AUTO_RESTART_CRON_FILE="$CRON_DIR/acore-manager-restart"
SERVICE_BACKUP_DIR="$BACKUP_DIR/systemd/$BACKUP_STAMP"
CRON_BACKUP_DIR="$BACKUP_DIR/cron/$BACKUP_STAMP"
changed_units=()
cron_changed=false
runtime_units_changed=false

usage() {
  cat <<EOF
Usage:
  $0 [--force] [--print-auto-restart-cron]

Installs or updates acore-manager systemd unit files and optional cron jobs.

Options:
  --force                    Replace existing managed units after backing them up.
  --print-auto-restart-cron  Print the rendered automatic restart cron file and exit.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      ;;
    --print-auto-restart-cron)
      PRINT_AUTO_RESTART_CRON=true
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

backup_existing_cron() {
  [[ -f "$AUTO_RESTART_CRON_FILE" ]] || return 0

  mkdir -p "$CRON_BACKUP_DIR"
  cp -a "$AUTO_RESTART_CRON_FILE" "$CRON_BACKUP_DIR/acore-manager-restart"
  echo "Backed up existing cron file: $AUTO_RESTART_CRON_FILE -> $CRON_BACKUP_DIR/acore-manager-restart"
}

validate_auto_restart_config() {
  local field_count

  field_count="$(awk '{ print NF }' <<<"${AUTO_RESTART_CRON:-}")"
  [[ "$field_count" -eq 5 ]] || die "AUTO_RESTART_CRON must be a standard 5-field cron expression, got: ${AUTO_RESTART_CRON:-}"
  [[ "${AUTO_RESTART_USER:-}" =~ ^[A-Za-z0-9_.-]+$ ]] || die "AUTO_RESTART_USER contains unsupported characters: ${AUTO_RESTART_USER:-}"
}

render_auto_restart_cron() {
  local command_path="$ACM_REPO_ROOT/bin/acore-manager"
  local log_path="$ACM_ROOT/logs/scheduled-restart.log"

  validate_auto_restart_config

  cat <<EOF
# Managed by acore-manager. Re-run:
#   sudo $command_path install-services --force
# to update this file from config/local/manager.conf.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

${AUTO_RESTART_CRON:-20 4 * * 3} ${AUTO_RESTART_USER:-root} $command_path scheduled-restart >> $log_path 2>&1
EOF
}

manage_auto_restart_cron() {
  log "Managing automatic restart cron"

  if is_truthy "${AUTO_RESTART_ENABLED:-false}"; then
    validate_auto_restart_config
    install -d -m 0755 "$CRON_DIR"
    install -d -m 0755 "$ACM_ROOT/logs"
    backup_existing_cron
    render_auto_restart_cron > "$AUTO_RESTART_CRON_FILE"
    chmod 0644 "$AUTO_RESTART_CRON_FILE"
    cron_changed=true
    echo "Installed automatic restart cron: $AUTO_RESTART_CRON_FILE"
    echo "Schedule: ${AUTO_RESTART_CRON:-20 4 * * 3}"
    echo "User: ${AUTO_RESTART_USER:-root}"
    return
  fi

  echo "Automatic restarts are disabled by config."
  echo "Default schedule if enabled: ${AUTO_RESTART_CRON:-20 4 * * 3}"
  echo "Enable with AUTO_RESTART_ENABLED=\"true\" in config/local/manager.conf, then rerun install-services."

  if [[ -f "$AUTO_RESTART_CRON_FILE" ]]; then
    backup_existing_cron
    rm -f "$AUTO_RESTART_CRON_FILE"
    cron_changed=true
    echo "Removed disabled automatic restart cron: $AUTO_RESTART_CRON_FILE"
  fi
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

if [[ "$PRINT_AUTO_RESTART_CRON" == "true" ]]; then
  render_auto_restart_cron
  exit 0
fi

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
manage_auto_restart_cron

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

if [[ -d "$CRON_BACKUP_DIR" ]]; then
  echo "Cron backups: $CRON_BACKUP_DIR"
fi

if [[ "$cron_changed" == "true" ]]; then
  echo "Automatic restart cron state was updated."
fi

if [[ "$runtime_units_changed" == "true" ]]; then
  echo
  echo "WARN: auth/world service templates changed. Live services were not restarted."
  echo "      Restart them explicitly during a maintenance window if the new unit settings should take effect now."
fi
