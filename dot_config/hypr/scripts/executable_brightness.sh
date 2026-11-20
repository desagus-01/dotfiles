#!/usr/bin/env sh
# Adjust the laptop panel through sysfs, otherwise use DDC/CI for external monitors.
# Requires DDC/CI to be enabled in the monitor's on-screen display.

set -eu

step=10
has_backlight() {
  [ -d /sys/class/backlight ] && [ -n "$(find /sys/class/backlight -mindepth 1 -maxdepth 1 -type l -print -quit)" ]
}

backlight_percent() {
  brightnessctl -m 2>/dev/null | awk -F, 'NR == 1 { gsub(/%/, "", $5); print $5 }'
}

# Map the focused Hyprland connector (for example, DP-2) to ddcutil's display
# number. DDC numbering is not guaranteed to match Hyprland monitor IDs.
ddc_display() {
  connector=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null || true)
  [ -n "$connector" ] && [ "$connector" != "null" ] || return 1

  ddcutil detect 2>/dev/null | awk -v connector="$connector" '
    $1 == "Display" { display = $2 }
    /DRM_connector:/ && $0 ~ ("-" connector "$") { print display; exit }
  '
}

ddc_percent() {
  display=$(ddc_display) || return 0
  ddcutil --sleep-multiplier=.2 --display="$display" getvcp 10 2>/dev/null |
    sed -n 's/.*current value = *\([0-9][0-9]*\), max value = *\([0-9][0-9]*\).*/\1 \2/p' |
    awk 'NR == 1 && $2 > 0 { printf "%d\n", ($1 * 100 + $2 / 2) / $2 }'
}

status() {
  if has_backlight; then
    percentage=$(backlight_percent || true)
    device="Laptop backlight"
  else
    percentage=$(ddc_percent || true)
    device="External monitor (DDC/CI)"
  fi

  if [ -n "${percentage:-}" ]; then
    printf '{"text":"%s%%","percentage":%s,"tooltip":"%s: %s%%"}\n' "$percentage" "$percentage" "$device" "$percentage"
  else
    printf '{"text":"--","percentage":0,"tooltip":"%s unavailable"}\n' "$device"
  fi
}

adjust() {
  case "$1" in
    +|-) ;;
    *) echo "Usage: $0 {+|-|status}" >&2; exit 2 ;;
  esac

  if has_backlight; then
    brightnessctl set "${step}%${1}" >/dev/null
  else
    display=$(ddc_display)
    ddcutil --sleep-multiplier=.2 --display="$display" setvcp 10 "$1" "$step" >/dev/null
  fi

  # Waybar's monitor-brightness module listens for SIGRTMIN+9 and immediately
  # re-runs its status command after a keyboard brightness adjustment.
  pkill -SIGRTMIN+9 waybar 2>/dev/null || true
}

case "${1:-status}" in
  status) status ;;
  +|-) adjust "$1" ;;
  *) echo "Usage: $0 {+|-|status}" >&2; exit 2 ;;
esac
