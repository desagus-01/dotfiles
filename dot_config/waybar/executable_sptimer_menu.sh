#!/usr/bin/env bash

set -euo pipefail

STATE_DIR="$HOME/.local/state/super-productivity-waybar-timer"
TIMER_FILE="$STATE_DIR/active.json"
HEARTBEAT_FILE="$STATE_DIR/heartbeat.json"
CONTROL_FILE="$STATE_DIR/session-control.json"

HEARTBEAT_SECONDS="$(stat -c %Y "$HEARTBEAT_FILE" 2>/dev/null || printf '0')"
HEARTBEAT_AGE=$(( $(date +%s) - HEARTBEAT_SECONDS ))
if [[ ! -s "$HEARTBEAT_FILE" ]] || (( HEARTBEAT_AGE > 15 || HEARTBEAT_AGE < -5 )); then
  notify-send "Super Productivity" "Open Super Productivity in the background to control this session." 2>/dev/null || true
  exit 0
fi

if [[ ! -s "$TIMER_FILE" ]]; then
  rofi -e "No active task session. Start one with SUPER+D."
  exit 0
fi

SESSION_STATE="$(jq -r '.sessionState // ""' "$TIMER_FILE")"
case "$SESSION_STATE" in
  running)
    MENU="End early\nPause"
    ;;
  paused)
    MENU="End early\nResume"
    ;;
  *)
    rofi -e "No allocated work session is active."
    exit 0
    ;;
esac

SELECTED_INDEX="$(printf '%b\n' "$MENU" | rofi -dmenu -i -no-custom -p "Work session" -format i)" || exit 0
case "$SESSION_STATE:$SELECTED_INDEX" in
  running:0 | paused:0) ACTION="end" ;;
  running:1) ACTION="pause" ;;
  paused:1) ACTION="resume" ;;
  *) exit 0 ;;
esac

mkdir -p "$STATE_DIR"
TEMP_FILE="$(mktemp "$STATE_DIR/session-control.XXXXXX")"
trap 'rm -f "$TEMP_FILE"' EXIT
jq -n --arg action "$ACTION" '{action: $action}' >"$TEMP_FILE"
chmod 600 "$TEMP_FILE"
mv -f "$TEMP_FILE" "$CONTROL_FILE"
trap - EXIT
