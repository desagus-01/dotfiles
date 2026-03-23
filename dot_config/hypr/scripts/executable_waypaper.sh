#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_SCRIPT="$HOME/.config/hypr/scripts/wallpaper.sh"

run_waypaper() {
  if command -v waypaper >/dev/null 2>&1; then
    waypaper "$@"
  else
    echo ":: waypaper not found"
    exit 1
  fi
}

if [[ "${1:-}" == "--random" ]]; then
  run_waypaper --random
  "$WALLPAPER_SCRIPT"
  exit 0
fi

run_waypaper "$@"
