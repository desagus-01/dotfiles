#!/usr/bin/env bash
set -euo pipefail

source "$HOME/.config/ml4w/library.sh"

# -----------------------------------------------------
# Check to use wallpaper cache
# -----------------------------------------------------
if [ -f "$HOME/.config/ml4w/settings/wallpaper_cache" ]; then
  use_cache=1
  _writeLog "Using Wallpaper Cache"
else
  use_cache=0
  _writeLog "Wallpaper Cache disabled"
fi

# -----------------------------------------------------
# Paths / folders
# -----------------------------------------------------
ml4w_cache_folder="$HOME/.cache/ml4w/hyprland-dotfiles"
generatedversions="$ml4w_cache_folder/wallpaper-generated"
mkdir -p "$ml4w_cache_folder" "$generatedversions"

waypaperrunning="$ml4w_cache_folder/waypaper-running"
[ -f "$waypaperrunning" ] && rm -f "$waypaperrunning" && _writeLog "Removed waypaper-running flag and continuing"

cachefile="$ml4w_cache_folder/current_wallpaper"
blurredwallpaper="$ml4w_cache_folder/blurred_wallpaper.png"
squarewallpaper="$ml4w_cache_folder/square_wallpaper.png"
rasifile="$ml4w_cache_folder/current_wallpaper.rasi"

blurfile="$HOME/.config/ml4w/settings/blur.sh"
defaultwallpaper="$HOME/.config/ml4w/wallpapers/default.jpg"
wallpapereffect="$HOME/.config/ml4w/settings/wallpaper-effect.sh"

fullwallpaper="$ml4w_cache_folder/wallpaper.png"
togglefile="$ml4w_cache_folder/.wallpaper_toggle"
statefile="$ml4w_cache_folder/.wallpaper_state"

# -----------------------------------------------------
# Read blur + effect
# -----------------------------------------------------
blur="$(cat "$blurfile" 2>/dev/null || echo "50x30")"
effect="off"
if [ -f "$wallpapereffect" ]; then
  effect="$(cat "$wallpapereffect")"
fi

# -----------------------------------------------------
# Get selected wallpaper
# -----------------------------------------------------
if [ -z "${1:-}" ]; then
  wallpaper="$(cat "$cachefile" 2>/dev/null || true)"
  [ -z "${wallpaper:-}" ] && wallpaper="$defaultwallpaper"
else
  wallpaper="$1"
fi

_writeLog "Setting wallpaper with source image $wallpaper"

# persist selection
mkdir -p "$(dirname "$cachefile")"
echo "$wallpaper" > "$cachefile"

wallpaperfilename="$(basename "$wallpaper")"
_writeLog "Wallpaper Filename: $wallpaperfilename"

# -----------------------------------------------------
# Resolve used_wallpaper (apply effect if needed)
# -----------------------------------------------------
force_generate=0
used_wallpaper="$wallpaper"

if [ "$effect" != "off" ]; then
  used_wallpaper="$generatedversions/$effect-$wallpaperfilename"
  if [ -f "$used_wallpaper" ] && [ "$force_generate" = "0" ] && [ "$use_cache" = "1" ]; then
    _writeLog "Use cached wallpaper $effect-$wallpaperfilename"
  else
    _writeLog "Generate new cached wallpaper $effect-$wallpaperfilename with effect $effect"
    notify-send --replace-id=1 "Using wallpaper effect $effect..." "with image $wallpaperfilename" -h int:value:33
    source "$HOME/.config/hypr/effects/wallpaper/$effect"
  fi
else
  _writeLog "Wallpaper effect is set to off"
fi

# -----------------------------------------------------
# Determine whether anything materially changed
# -----------------------------------------------------
cache_key="${wallpaper}|effect=${effect}|blur=${blur}"
prev_key="$(cat "$statefile" 2>/dev/null || true)"

# helper: ensure hyprpaper is running
ensure_hyprpaper() {
  if ! pgrep -x hyprpaper >/dev/null; then
    nohup hyprpaper >/dev/null 2>&1 &
    _writeLog "Started hyprpaper"
    sleep 0.2
  fi
}

# helper: apply wallpaper via IPC (no restart)
apply_ipc() {
  local applywallpaper="$1"
  ensure_hyprpaper
  local monitors_txt
  monitors_txt="$(hyprctl monitors 2>/dev/null || true)"

  if echo "$monitors_txt" | grep -q "Monitor HDMI-A-1"; then
    hyprctl hyprpaper wallpaper "HDMI-A-1,$applywallpaper"
  fi
  if echo "$monitors_txt" | grep -q "Monitor DP-2"; then
    hyprctl hyprpaper wallpaper "DP-2,$applywallpaper"
  fi
  if echo "$monitors_txt" | grep -q "Monitor eDP-1"; then
    hyprctl hyprpaper wallpaper "eDP-1,$applywallpaper"
  fi

  # fallback
  if ! echo "$monitors_txt" | grep -q "Monitor HDMI-A-1\|Monitor DP-2\|Monitor eDP-1"; then
    hyprctl hyprpaper wallpaper ",$applywallpaper"
  fi
}

# -----------------------------------------------------
# Always re-apply, only regenerate heavy assets if needed
# -----------------------------------------------------
toggle="0"
[ -f "$togglefile" ] && toggle="$(cat "$togglefile")"
[ "$toggle" = "0" ] && toggle="1" || toggle="0"
echo "$toggle" > "$togglefile"
applywallpaper="$ml4w_cache_folder/wallpaper_apply_${toggle}.png"

needs_regen=1

if [ "$cache_key" = "$prev_key" ] && [ -f "$fullwallpaper" ]; then
  needs_regen=0
  _writeLog "Wallpaper state unchanged; doing fast re-apply"
  cp -f "$fullwallpaper" "$applywallpaper"
else
  _writeLog "Updating full wallpaper cache: $fullwallpaper"
  cp -f "$used_wallpaper" "$fullwallpaper"
  cp -f "$fullwallpaper" "$applywallpaper"
fi

apply_ipc "$applywallpaper"
_writeLog "Applied wallpaper via hyprpaper IPC"

# -----------------------------------------------------
# Create square wallpaper (only when key changed or missing)
# -----------------------------------------------------
if [ "$needs_regen" = "1" ] || [ ! -f "$squarewallpaper" ]; then
  _writeLog "Generate square wallpaper"
  magick "$used_wallpaper" -gravity Center -extent 1:1 "$squarewallpaper"
  cp -f "$squarewallpaper" "$generatedversions/square-$wallpaperfilename.png"
else
  _writeLog "Square wallpaper unchanged; reusing cached version"
fi

# -----------------------------------------------------
# Detect Theme + run matugen (always run)
# -----------------------------------------------------
SETTINGS_FILE="$HOME/.config/gtk-3.0/settings.ini"
THEME_PREF="$(grep -E '^gtk-application-prefer-dark-theme=' "$SETTINGS_FILE" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"

MATUGEN_BIN="${MATUGEN_BIN:-$(command -v matugen 2>/dev/null || true)}"

if [ -z "$MATUGEN_BIN" ]; then
  for candidate in "$HOME/.cargo/bin/matugen" "$HOME/.local/bin/matugen" "/usr/bin/matugen"; do
    if [ -x "$candidate" ]; then
      MATUGEN_BIN="$candidate"
      break
    fi
  done
fi

if [ -n "$MATUGEN_BIN" ] && [ -x "$MATUGEN_BIN" ]; then
  if [ "${THEME_PREF:-0}" = "1" ]; then
    _writeLog "Running matugen in dark mode via $MATUGEN_BIN"
    "$MATUGEN_BIN" image "$squarewallpaper" -m dark
  else
    _writeLog "Running matugen in light mode via $MATUGEN_BIN"
    "$MATUGEN_BIN" image "$squarewallpaper" -m light
  fi
else
  _writeLog "ERROR: matugen not found in PATH or common locations"
fi

# -----------------------------------------------------
# Blur wallpaper (regenerate only when needed)
# -----------------------------------------------------
blur_cache="$generatedversions/blur-$blur-$effect-$wallpaperfilename.png"
if [ "$needs_regen" = "1" ] || [ ! -f "$blur_cache" ] || [ "$force_generate" = "1" ] || [ "$use_cache" != "1" ]; then
  _writeLog "Generate blurred wallpaper $(basename "$blur_cache") with blur $blur"
  magick "$used_wallpaper" -resize 75% "$blurredwallpaper"
  if [ "$blur" != "0x0" ]; then
    magick "$blurredwallpaper" -blur "$blur" "$blurredwallpaper"
  fi
  cp -f "$blurredwallpaper" "$blur_cache"
else
  _writeLog "Use cached blurred wallpaper $(basename "$blur_cache")"
fi
cp -f "$blur_cache" "$blurredwallpaper"

# -----------------------------------------------------
# Create rasi file
# -----------------------------------------------------
echo "* { current-image: url(\"$blurredwallpaper\", height); }" >"$rasifile"

# -----------------------------------------------------
# Reload UI bits
# -----------------------------------------------------
pkill -USR2 waybar 2>/dev/null || true
sleep 0.1
swaync-client -rs

# -----------------------------------------------------
# Save state key
# -----------------------------------------------------
echo "$cache_key" >"$statefile"
_writeLog "Saved wallpaper state key"
