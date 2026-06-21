#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

show_unit() {
  local service="$1"
  local label="$2"

  echo "$label: $service"
  if ! systemd_available; then
    echo "  systemctl: unavailable"
    return
  fi
  if systemd_unit_exists "$service"; then
    echo "  active: $(systemctl is-active "$service" 2>/dev/null || true)"
    echo "  enabled: $(systemctl is-enabled "$service" 2>/dev/null || true)"
    echo "  failed: $(systemctl is-failed "$service" 2>/dev/null || true)"
  else
    echo "  installed: no"
  fi
}

log "Managed Services"
show_unit "$AUTH_SERVICE" "Auth"
show_unit "$WORLD_SERVICE" "World"
show_unit "acore-sleep-proxy.service" "Sleep proxy"
show_unit "acore-sleep-monitor.service" "Sleep monitor"
show_unit "acore-manager-shutdown.service" "Shutdown hook"

log "Cron"
cron_file="/etc/cron.d/acore-manager-restart"
if [[ -f "$cron_file" ]]; then
  echo "Automatic restart cron: installed ($cron_file)"
  sed 's/^/  /' "$cron_file"
else
  echo "Automatic restart cron: not installed ($cron_file)"
fi

