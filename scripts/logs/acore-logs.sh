#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

service=""
lines="100"

usage() {
  cat <<EOF
Usage:
  $0 --service auth|world|sleep|proxy|manager [--lines N]
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --service) service="${2:-}"; shift ;;
    --lines) lines="${2:-}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

[[ "$lines" =~ ^[0-9]+$ ]] || die "--lines must be a number"

case "$service" in
  auth) unit="$AUTH_SERVICE" ;;
  world) unit="$WORLD_SERVICE" ;;
  sleep) unit="acore-sleep-monitor.service" ;;
  proxy) unit="acore-sleep-proxy.service" ;;
  manager) unit="acore-manager-shutdown.service" ;;
  *) die "--service must be one of: auth, world, sleep, proxy, manager" ;;
esac

command -v journalctl >/dev/null 2>&1 || die "journalctl is not available"
echo "Service: $unit"
journalctl -u "$unit" -n "$lines" --no-pager

