#!/usr/bin/env bash
set -euo pipefail

# Reload Waybar after Hyprland has applied a monitor hot-plug change.  Waybar
# creates one instance per enabled output, so the same configuration works for
# both the laptop-only and docked arrangements.
pkill -x waybar 2>/dev/null || true
sleep 0.2
exec waybar \
    -c "$HOME/.config/waybar/themes/gus-config/config" \
    -s "$HOME/.config/waybar/themes/gus-config/colored/style.css"
