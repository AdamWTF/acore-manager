#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

show_service_status() {
  local service="$1"
  local label="$2"

  echo "$label service: $service"

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "  WARN: systemctl is not available"
    return
  fi

  if systemctl list-unit-files "$service" >/dev/null 2>&1; then
    echo "  Active: $(systemctl is-active "$service" 2>/dev/null || true)"
    echo "  Enabled: $(systemctl is-enabled "$service" 2>/dev/null || true)"
  else
    echo "  WARN: service unit was not found"
  fi
}

show_listening_ports() {
  local ports=(3724 8085 7878 3443)

  if command -v ss >/dev/null 2>&1; then
    for port in "${ports[@]}"; do
      if ss -ltn "sport = :$port" 2>/dev/null | awk 'NR > 1 { found = 1 } END { exit !found }'; then
        echo "  $port: listening"
      else
        echo "  $port: not detected"
      fi
    done
    return
  fi

  if command -v netstat >/dev/null 2>&1; then
    for port in "${ports[@]}"; do
      if netstat -ltn 2>/dev/null | awk -v port=":$port" '$4 ~ port "$" { found = 1 } END { exit !found }'; then
        echo "  $port: listening"
      else
        echo "  $port: not detected"
      fi
    done
    return
  fi

  echo "  WARN: neither ss nor netstat is available"
}

log "Active Release"
if [[ -e "$CURRENT_LINK" || -L "$CURRENT_LINK" ]]; then
  if command -v readlink >/dev/null 2>&1; then
    current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || readlink "$CURRENT_LINK")"
    echo "$CURRENT_LINK -> $current_target"
    case "$current_target" in
      "$BUILD_DIR"/staging|"$BUILD_DIR"/staging/*)
        echo "ERROR: current points to build staging; switch to a release under $RELEASES_DIR"
        ;;
      "$RELEASES_DIR"/*)
        echo "Runtime path: $CURRENT_LINK"
        ;;
      *)
        echo "WARN: current does not point under releases: $current_target"
        ;;
    esac
  else
    echo "$CURRENT_LINK exists"
  fi
else
  echo "WARN: current release link does not exist: $CURRENT_LINK"
fi

if [[ -x "$CURRENT_LINK/bin/authserver" ]]; then
  echo "OK: auth binary: $CURRENT_LINK/bin/authserver"
else
  echo "WARN: auth binary missing: $CURRENT_LINK/bin/authserver"
fi

if [[ -x "$CURRENT_LINK/bin/worldserver" ]]; then
  echo "OK: world binary: $CURRENT_LINK/bin/worldserver"
else
  echo "WARN: world binary missing: $CURRENT_LINK/bin/worldserver"
fi

log "Services"
show_service_status "$AUTH_SERVICE" "Auth"
show_service_status "$WORLD_SERVICE" "World"

log "Listening Ports"
show_listening_ports

log "Disk Usage"
if [[ -e "$ACM_ROOT" ]]; then
  df -h "$ACM_ROOT" 2>/dev/null || echo "WARN: unable to read disk usage for $ACM_ROOT"
else
  echo "WARN: ACM_ROOT does not exist: $ACM_ROOT"
fi

log "Memory Usage"
if command -v free >/dev/null 2>&1; then
  free -h
else
  echo "WARN: free is not available"
fi

log "Source Commit"
if [[ -d "$ACORE_SOURCE_DIR/.git" ]]; then
  git -C "$ACORE_SOURCE_DIR" rev-parse --short HEAD
  git -C "$ACORE_SOURCE_DIR" log -1 --pretty='format:%h %ci %s%n'
else
  echo "WARN: ACORE_SOURCE_DIR is not a git repository: $ACORE_SOURCE_DIR"
fi
