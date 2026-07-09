#!/usr/bin/env bash

# 1. Path to your wallpaper directory
WALL_DIR="$HOME/Pictures/Wallpapers"

if [ ! -d "$WALL_DIR" ]; then
    notify-send "Wallpaper Picker" "Directory not found: $WALL_DIR"
    exit 1
fi

# List of nice swww animations (excluding 'none' and 'random' for explicit control)
TRANSITIONS=("grow" "wave" "wipe" "outer" "center" "any")
# Pick a random transition from the array
RANDOM_TRANSITION=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}

# 2. Format files specifically so Rofi processes them as internal icons
function list_wallpapers() {
    for img in "$WALL_DIR"/*.{jpg,jpeg,png,webp}; do
        if [ -f "$img" ]; then
            basename=$(basename "$img")
            echo -en "$basename\0icon\x1f$img\n"
        fi
    done
}

# 3. Call Rofi with the icon string stream
CHOICE=$(list_wallpapers | rofi -dmenu -config ~/.config/rofi/wallpaper.rasi -p "Select Wallpaper")

if [ -z "$CHOICE" ]; then
    exit 0
fi

WP_PATH="$WALL_DIR/$CHOICE"

# 4. Apply using awww with a random animation
if awww img "$WP_PATH" \
    --transition-type "$RANDOM_TRANSITION" \
    --transition-fps 60 \
    --transition-duration 1.5 \
    --transition-wave "20,20"; then
    
    # Update the symlink for hyprlock to follow
    ln -sf "$WP_PATH" "$HOME/.config/hypr/scripts/hyprlock/current_wallpaper.png"
    
    notify-send "Wallpaper Updated" "Applied: $CHOICE" -i "$WP_PATH"
else
    notify-send "Wallpaper Error" "Failed to apply wallpaper." -u critical
fi