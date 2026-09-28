#!/usr/bin/env bash

options="Shutdown\nReboot\nLock\nSuspend\nLogout"

choice=$(echo -e "$options" | rofi -dmenu -config ~/.config/rofi/powermenu.rasi -p "Power:")

case "$choice" in
    "Shutdown") systemctl poweroff ;;
    "Reboot") systemctl reboot ;;
    "Lock") hyprlock || swaylock ;;
    "Suspend") systemctl suspend ;;
    "Logout") hyprctl dispatch exit ;;
esac