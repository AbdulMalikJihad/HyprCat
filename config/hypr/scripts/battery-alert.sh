#!/bin/bash

# Define thresholds
LOW=35
CRITICAL=20
HIBERNATE_LEVEL=8

# Get capacity and status from sysfs
PERCENT=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")

# File paths for state/notification tracking
STATE_FILE="/tmp/bat_state"
LOW_FLAG="/tmp/bat_low_notified"
CRIT_FLAG="/tmp/bat_crit_notified"
LOCK_DIR="/tmp/bat_script.lock"

# Prevent multiple script instances from overlapping using a directory lock
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

# --- POWER PLUG / UNPLUG NOTIFICATIONS WITH DEBOUNCE ---
if [ -f "$STATE_FILE" ]; then
    PREV_STATUS=$(cat "$STATE_FILE")
    if [ "$STATUS" != "$PREV_STATUS" ]; then
        if [ "$STATUS" = "Charging" ]; then
            notify-send -u normal -t 3000 "󰂄 Charger Connected" "Battery is charging at ${PERCENT}%."
            rm -f "$LOW_FLAG" "$CRIT_FLAG"
        elif [ "$STATUS" = "Discharging" ]; then
            notify-send -u normal -t 3000 "󰚥 Charger Disconnected" "Running on battery power (${PERCENT}%)."
        fi
        echo "$STATUS" > "$STATE_FILE"
    fi
else
    echo "$STATUS" > "$STATE_FILE"
fi

# --- BATTERY ALERT & AUTO-ACTION LOGIC ---
if [ "$STATUS" = "Discharging" ]; then
    # Emergency Hibernate/Suspend if battery suddenly drops below safety margin
    if [ "$PERCENT" -le "$HIBERNATE_LEVEL" ]; then
        notify-send -u critical "CRITICAL BATTERY" "Battery at ${PERCENT}%. Suspending system now!"
        sleep 2
        systemctl suspend || systemctl hibernate
    # Critical Alert
    elif [ "$PERCENT" -le "$CRITICAL" ]; then
        if [ ! -f "$CRIT_FLAG" ]; then
            notify-send -u critical -t 0 "CRITICAL BATTERY" "Plug in charger immediately! Battery is at ${PERCENT}%."
            touch "$CRIT_FLAG"
        fi
    # Low Alert
    elif [ "$PERCENT" -le "$LOW" ]; then
        if [ ! -f "$LOW_FLAG" ]; then
            notify-send -u normal "Low Battery" "Battery level dropping. Currently at ${PERCENT}%."
            touch "$LOW_FLAG"
        fi
    fi
else
    # Clear flags when charging or full
    rm -f "$LOW_FLAG" "$CRIT_FLAG"
fi