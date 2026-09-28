#!/usr/bin/env bash

THEME="$HOME/.config/rofi/emoji.rasi"
EMOJI_LIST="$HOME/.config/hypr/scripts/emoji-list.txt"

show_result() {
    local title="$1" body="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body"
    else
        rofi -theme "$THEME" -e "$title: $body"
    fi
}

if [ ! -f "$EMOJI_LIST" ]; then
    show_result "Emoji Picker" "Missing $EMOJI_LIST"
    exit 1
fi

# Display as "<emoji> <Name>" so rofi's fuzzy search matches on the name
# (e.g. typing "cyclone" finds 🌀). The emoji itself never contains a
# space, so pulling it back out on selection is just "everything before
# the first space" — no fragile column parsing needed.
chosen=$(awk -F'\t' '{print $1 " " $2}' "$EMOJI_LIST" | rofi -dmenu -p "Emoji" -theme "$THEME")

if [ -z "$chosen" ]; then exit 0; fi

emoji="${chosen%% *}"

if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$emoji" | wl-copy
    show_result "Emoji Picker" "Copied $emoji to clipboard"
elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$emoji" | xclip -selection clipboard
    show_result "Emoji Picker" "Copied $emoji to clipboard"
else
    show_result "Emoji Picker" "No clipboard tool found (install wl-clipboard)"
    exit 1
fi
