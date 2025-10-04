#!/bin/bash

LAST_UPDATE_FILE="$HOME/.last_update_check"

# Create file if it doesn't exist
if [ ! -f "$LAST_UPDATE_FILE" ]; then
    echo 0 > "$LAST_UPDATE_FILE"
fi

# Calculate days since last update
NOW=$(date +%s)
LAST=$(cat "$LAST_UPDATE_FILE")
DIFF=$(( (NOW - LAST) / 86400 ))  # in days

if [ "$DIFF" -ge 7 ]; then
    echo '{ "text": "🛠️ UPDATE!", "tooltip": "You haven'\''t updated in 7+ days", "class": "danger" }'
else
    echo '{ "text": "", "tooltip": "", "class": "" }'
fi
