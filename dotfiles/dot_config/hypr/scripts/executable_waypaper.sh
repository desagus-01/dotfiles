
#!/usr/bin/env bash
set -euo pipefail

WAYPAPER_BIN=""
if command -v waypaper >/dev/null 2>&1; then
  WAYPAPER_BIN="$(command -v waypaper)"
elif [ -x "$HOME/.local/bin/waypaper" ]; then
  WAYPAPER_BIN="$HOME/.local/bin/waypaper"
else
  echo ":: waypaper not found"
  exit 1
fi

echo ":: Launching waypaper: $WAYPAPER_BIN"
"$WAYPAPER_BIN" "$@"

# When the UI closes, apply whatever was selected (your script handles reading cache/defaults)
"$HOME/.config/hypr/scripts/wallpaper.sh"

