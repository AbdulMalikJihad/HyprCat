#!/usr/bin/env bash

# Run rofi with a custom keybinding (kb-custom-1) mapped to Alt+Delete
selection=$(cliphist list | rofi -dmenu \
    -config ~/.config/rofi/clipboard.rasi \
    -p "󰅌 Clipboard" \
    -kb-custom-1 "Alt+Delete")

exit_code=$?

# If the user presses Alt+Delete (exit code 10 means custom key 1 was pressed)
if [ $exit_code -eq 10 ]; then
    confirm=$(echo -e "No\nYes" | rofi -dmenu -config ~/.config/rofi/clipboard.rasi -p "󰆴 Clear all history?")
    if [ "$confirm" = "Yes" ]; then
        cliphist wipe
    fi
# If the user made a normal selection
elif [ -n "$selection" ] && [ $exit_code -eq 0 ]; then
    echo "$selection" | cliphist decode | wl-copy && sleep 0.1 && wtype -M ctrl v
fi