#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

APPLY=false
keep_count="${ACORE_RELEASE_KEEP_COUNT:-5}"

usage() {
  cat <<EOF
Usage:
  $0 [--keep N] [--dry-run]
  $0 [--keep N] --apply

Dry-run is the default. --apply is required to delete releases.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --keep)
      keep_count="${2:-}"
      shift
      ;;
    --dry-run)
      APPLY=false
      ;;
    --apply)
      APPLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        keep_count="$1"
      else
        die "unknown argument: $1"
      fi
      ;;
  esac
  shift
done

[[ "$keep_count" =~ ^[0-9]+$ ]] || die "keep count must be a non-negative integer: $keep_count"

active_release=""
if [[ -L "$CURRENT_LINK" ]]; then
  active_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
  if [[ -n "$active_target" ]]; then
    active_release="$(basename "$active_target")"
  fi
fi

if [[ ! -d "$RELEASES_DIR" ]]; then
  if [[ "$APPLY" == "true" ]]; then
    die "RELEASES_DIR does not exist: $RELEASES_DIR"
  fi
  log "Pruning releases"
  echo "Releases directory does not exist yet: $RELEASES_DIR"
  echo "Dry-run only. Nothing would be pruned."
  exit 0
fi

mapfile -t releases < <(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)

declare -A keep=()
kept_recent=0
for release in "${releases[@]}"; do
  if [[ "$kept_recent" -lt "$keep_count" ]]; then
    keep["$release"]=1
    kept_recent=$((kept_recent + 1))
  fi
done

if [[ -n "$active_release" ]]; then
  keep["$active_release"]=1
fi

log "Pruning releases"
echo "Releases directory: $RELEASES_DIR"
echo "Keep recent count: $keep_count"
echo "Active release: ${active_release:-none}"
echo "Mode: $([[ "$APPLY" == "true" ]] && echo apply || echo dry-run)"
echo

for release in "${releases[@]}"; do
  release_dir="$RELEASES_DIR/$release"

  if [[ -n "${keep[$release]:-}" ]]; then
    echo "Keeping: $release"
  else
    if [[ "$APPLY" == "true" ]]; then
      echo "Pruning: $release"
      rm -rf -- "$release_dir"
    else
      echo "Would prune: $release"
    fi
  fi
done

if [[ "$APPLY" != "true" ]]; then
  echo
  echo "Dry-run only. Re-run with --apply to delete listed releases."
fi
