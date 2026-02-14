
#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_SCRIPT="$HOME/.config/hypr/scripts/wallpaper.sh"

run_waypaper() {
  if [ -x /usr/bin/waypaper ]; then
    /usr/bin/waypaper "$@"
  elif [ -x "$HOME/.local/bin/waypaper" ]; then
    "$HOME/.local/bin/waypaper" "$@"
  else
    echo ":: waypaper not found"
    exit 1
  fi
}

# If random, run in foreground then apply
if [[ "${1:-}" == "--random" ]]; then
  run_waypaper --random
  "$WALLPAPER_SCRIPT"
  exit 0
fi

# Otherwise open UI (background is fine here)
run_waypaper "${1:-}" &
disown

