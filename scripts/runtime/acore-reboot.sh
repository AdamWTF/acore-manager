#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

FORCE=false

usage() {
  cat <<EOF
Usage:
  $0 [--force]

Runs safe-stop and then reboots the host with systemctl reboot.

Options:
  --force  Reboot even if safe-stop reports a failure.
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
      die "unknown reboot option: $1"
      ;;
  esac
  shift
done

systemd_available || die "systemctl is not available"

safe_stop="$ACM_REPO_ROOT/scripts/runtime/acore-safe-stop.sh"
[[ -x "$safe_stop" ]] || die "safe-stop script is missing or not executable: $safe_stop"

log "Running safe-stop before reboot"
if "$safe_stop"; then
  echo "safe-stop succeeded; rebooting host"
elif [[ "$FORCE" == "true" ]]; then
  echo "WARN: safe-stop failed; --force supplied, rebooting anyway"
else
  die "safe-stop failed; refusing to reboot without --force"
fi

systemctl reboot

