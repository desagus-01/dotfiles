#!/usr/bin/env bash

set -euo pipefail

STATE_DIR="$HOME/.local/state/super-productivity-waybar-timer"
TODAY_FILE="$STATE_DIR/today.json"
HEARTBEAT_FILE="$STATE_DIR/heartbeat.json"
REQUEST_FILE="$STATE_DIR/start-task.json"

app_process_running() {
  pgrep -f -- '[s]uper-productivity/app.asar' >/dev/null 2>&1
}

heartbeat_is_fresh() {
  [[ -s "$HEARTBEAT_FILE" ]] || return 1
  local heartbeat_ms now_ms age_ms
  heartbeat_ms="$(jq -er '(.updatedAtMs // 0) | numbers' "$HEARTBEAT_FILE" 2>/dev/null)" || return 1
  now_ms="$(date +%s%3N)"
  age_ms=$((now_ms - heartbeat_ms))
  (( age_ms <= 15000 && age_ms >= -5000 ))
}

app_ready_after() {
  local launched_at_ms="$1"
  app_process_running || return 1
  heartbeat_is_fresh || return 1
  [[ -s "$TODAY_FILE" ]] || return 1
  local heartbeat_ms
  heartbeat_ms="$(jq -er '(.updatedAtMs // 0) | numbers' "$HEARTBEAT_FILE" 2>/dev/null)" || return 1
  (( heartbeat_ms >= launched_at_ms ))
}

if ! app_process_running || ! heartbeat_is_fresh || [[ ! -s "$TODAY_FILE" ]]; then
  if ! command -v super-productivity >/dev/null 2>&1; then
    notify-send "Super Productivity" "Could not find the Super Productivity desktop app." 2>/dev/null || true
    exit 0
  fi

  LAUNCHED_AT_MS="$(date +%s%3N)"
  if ! app_process_running; then
    # The installed app supports --start-minimized. Its tray is enabled, so the
    # main window stays hidden while the plugin and local task picker start.
    super-productivity --start-minimized >/dev/null 2>&1 </dev/null &
  fi

  APP_READY=0
  for _ in {1..60}; do
    if app_ready_after "$LAUNCHED_AT_MS"; then
      APP_READY=1
      break
    fi
    sleep 0.5
  done

  if (( APP_READY == 0 )); then
    notify-send "Super Productivity" "The app did not become ready. Open it once and approve the Waybar Timer plugin permission." 2>/dev/null || true
    exit 0
  fi
fi

TASK_COUNT="$(jq '.tasks | length' "$TODAY_FILE")"
if [[ "$TASK_COUNT" -eq 0 ]]; then
  rofi -e "No unfinished tasks are planned for today."
  exit 0
fi

OPTIONS="$(jq -r '
  def duration($ms):
    (($ms / 60000) | round) as $minutes
    | if $minutes >= 60
      then "\(($minutes / 60) | floor)h \($minutes % 60)m"
      else "\($minutes)m"
      end;
  .tasks[]
  | (.title | gsub("[\\r\\n\\t]"; " ")) as $title
  | if (.timeEstimateMs // 0) > 0 then
      ((.timeEstimateMs - (.timeSpentMs // 0)) as $raw
       | (if $raw > 0 then $raw else 0 end) as $net
       | $title + "   ·   NET " + duration($net))
    else
      $title + "   ·   no estimate"
    end
' "$TODAY_FILE")"

SELECTED_INDEX="$(printf '%s\n' "$OPTIONS" | rofi -dmenu -i -no-custom -p "Start today's task" -format i)" || exit 0
[[ "$SELECTED_INDEX" =~ ^[0-9]+$ ]] || exit 0

TASK_ID="$(jq -r --argjson index "$SELECTED_INDEX" '.tasks[$index].id // empty' "$TODAY_FILE")"
[[ -n "$TASK_ID" ]] || exit 0

SESSION_INDEX="$(printf '15 minutes\n25 minutes\n30 minutes\n45 minutes\n60 minutes\nCustom…\n' | rofi -dmenu -i -no-custom -p "Allocate time" -format i)" || exit 0
[[ "$SESSION_INDEX" =~ ^[0-5]$ ]] || exit 0

case "$SESSION_INDEX" in
  0) SESSION_MINUTES=15 ;;
  1) SESSION_MINUTES=25 ;;
  2) SESSION_MINUTES=30 ;;
  3) SESSION_MINUTES=45 ;;
  4) SESSION_MINUTES=60 ;;
  5)
    CUSTOM_MINUTES="$(rofi -dmenu -i -p "Custom minutes (1-480)" -format s </dev/null)" || exit 0
    [[ "$CUSTOM_MINUTES" =~ ^[0-9]+$ ]] || {
      rofi -e "Enter a whole number of minutes from 1 to 480."
      exit 0
    }
    SESSION_MINUTES="$CUSTOM_MINUTES"
    if (( SESSION_MINUTES < 1 || SESSION_MINUTES > 480 )); then
      rofi -e "Enter a whole number of minutes from 1 to 480."
      exit 0
    fi
    ;;
esac

mkdir -p "$STATE_DIR"
TEMP_FILE="$(mktemp "$STATE_DIR/start-task.XXXXXX")"
trap 'rm -f "$TEMP_FILE"' EXIT
jq -n --arg taskId "$TASK_ID" --argjson sessionMinutes "$SESSION_MINUTES" \
  '{taskId: $taskId, sessionMinutes: $sessionMinutes}' >"$TEMP_FILE"
chmod 600 "$TEMP_FILE"
mv -f "$TEMP_FILE" "$REQUEST_FILE"
trap - EXIT
