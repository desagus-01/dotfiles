#!/bin/bash

# Run your updateall script in a terminal window
# Replace `foot` with your terminal (kitty, alacritty, gnome-terminal, etc.)
foot -e kitty -c "~/updateall.sh; read -p 'Press enter to close...'"

# Timestamp is already saved by updateall.sh
