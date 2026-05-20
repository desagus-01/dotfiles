#!/usr/bin/env bash

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
output="${WAYBAR_OUTPUT_NAME:-}"

ws_id=""

if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  if [ -n "$output" ]; then
    ws_id="$(
      hyprctl monitors -j |
        jq -r --arg output "$output" \
          '.[] | select(.name == $output) | .activeWorkspace.id // empty'
    )"
  fi

  if [ -z "$ws_id" ]; then
    ws_id="$(
      hyprctl activeworkspace -j |
        jq -r '.id // empty'
    )"
  fi
fi

if [ -z "$ws_id" ]; then
  printf '{"text":"?","tooltip":"Could not detect workspace","class":"unknown"}\n'
  exit 0
fi

state_file="$runtime_dir/hypr-layout-ws-$ws_id"
layout="$(cat "$state_file" 2>/dev/null)"

# Default to dwindle if this workspace has not been written yet.
# This keeps startup sane, since dwindle is usually the default layout.
if [ -z "$layout" ]; then
  layout="dwindle"
fi

case "$layout" in
  scrolling)
    printf '{"text":"S","tooltip":"Workspace %s: scrolling","class":"scrolling"}\n' "$ws_id"
    ;;
  dwindle)
    printf '{"text":"D","tooltip":"Workspace %s: dwindle","class":"dwindle"}\n' "$ws_id"
    ;;
  *)
    printf '{"text":"?","tooltip":"Workspace %s: unknown layout","class":"unknown"}\n' "$ws_id"
    ;;
esac
