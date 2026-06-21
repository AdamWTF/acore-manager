#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

usage() {
  cat <<EOF
Usage:
  $0 <release-name>
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

release_name="${1:-}"
[[ -n "$release_name" ]] || die "usage: $0 <release-name>"
[[ "$release_name" != *"/"* ]] || die "release name must not contain slashes: $release_name"

release_dir="$RELEASES_DIR/$release_name"
[[ -d "$release_dir" ]] || die "release does not exist: $release_dir"

active_target=""
if [[ -L "$CURRENT_LINK" ]]; then
  active_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
fi

log "Release report"
echo "Release: $release_name"
echo "Path: $release_dir"
echo "Active: $([[ "$active_target" == "$(readlink -f "$release_dir" 2>/dev/null || true)" ]] && echo yes || echo no)"

log "Binaries"
for binary in authserver worldserver; do
  if [[ -x "$release_dir/bin/$binary" ]]; then
    echo "OK: bin/$binary"
  else
    echo "MISSING: bin/$binary"
  fi
done

log "Config templates"
for path in etc.dist/authserver.conf.dist etc.dist/worldserver.conf.dist etc/authserver.conf etc/worldserver.conf; do
  [[ -e "$release_dir/$path" ]] && echo "present: $path"
done

log "Metadata"
if [[ -d "$release_dir/metadata" ]]; then
  find "$release_dir/metadata" -maxdepth 1 -type f -print | sort | while IFS= read -r file; do
    echo "== $(basename "$file") =="
    sed -n '1,80p' "$file"
  done
else
  echo "No metadata directory found."
fi
