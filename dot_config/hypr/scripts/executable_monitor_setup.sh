#!/usr/bin/env bash
set -euo pipefail

external_output="DP-4"
workspace_source="$HOME/.config/waybar/custom_workspaces.json"
workspace_runtime="$HOME/.cache/waybar/custom_workspaces.json"

external_connected() {
    local status
    for status in /sys/class/drm/*-"$external_output"/status; do
        [[ -e "$status" ]] || continue
        [[ "$(<"$status")" == "connected" ]] && return 0
    done

    return 1
}

write_runtime_workspace_config() {
    mkdir -p "$(dirname "$workspace_runtime")"

    if external_connected; then
        # Docked: match the PC style and show workspace numbers on Waybar.
        sed '0,/"format": "{windows}",/s//"format": "{name}: {windows}",/' \
            "$workspace_source" >"$workspace_runtime"
    else
        # Laptop only: keep the workspace icons/windows without numeric labels.
        cp "$workspace_source" "$workspace_runtime"
    fi
}

# Reload Waybar after Hyprland has applied a monitor hot-plug change.  Waybar
# creates one instance per enabled output, so the same configuration works for
# both the laptop-only and docked arrangements.
write_runtime_workspace_config
pkill -x waybar 2>/dev/null || true
sleep 0.2
exec waybar \
    -c "$HOME/.config/waybar/themes/gus-config/config" \
    -s "$HOME/.config/waybar/themes/gus-config/colored/style.css"
