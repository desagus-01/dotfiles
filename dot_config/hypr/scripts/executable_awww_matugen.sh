#!/usr/bin/env bash
set -euo pipefail

# Make Hyprland keybind environment closer to your terminal
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

wallpaper="${1:?No wallpaper path received}"

# Generate Matugen colours from the wallpaper Waypaper just selected
matugen image "$wallpaper"

# Create unblurred rasi wallpaper
mkdir -p "$HOME/.cache/ml4w/hyprland-dotfiles"
cp -f "$wallpaper" "$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper.png"
echo "* { current-image: url(\"$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper.png\", height); }" > "$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper.rasi"

# Reload Waybar so it picks up the new generated colours
pkill -x waybar || true
sleep 0.2

waybar \
  -c "$HOME/.config/waybar/themes/gus-config/config" \
  -s "$HOME/.config/waybar/themes/gus-config/colored/style.css" &
