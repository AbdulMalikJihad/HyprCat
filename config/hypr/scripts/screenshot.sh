#!/usr/bin/env bash

# 1. Define paths
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"
FILE_PATH="$SAVE_DIR/Screenshot_$(date +'%Y%m%d_%H%M%S').png"

# 2. Rofi Options
OPTIONS="󰹑 Fullscreen\n󰒅 Region Selection"

# 3. Present the tiny selection menu
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu \
    -p "Capture" \
    -theme-str 'window {width: 300px; height: 200px; border: 2px; border-radius: 10px; border-color: #cba6f7;} listview {lines: 2; spacing: 10px;} element {padding: 10px;}')

# 4. Take action based on selection
case "$CHOICE" in
    *"Fullscreen"*)
        sleep 0.2 # Give Rofi a split second to close fully
        grim - | swappy -f - -o "$FILE_PATH"
        ;;
    *"Region Selection"*)
        grim -g "$(slurp)" - | swappy -f - -o "$FILE_PATH"
        ;;
    *)
        exit 0
        ;;
esac