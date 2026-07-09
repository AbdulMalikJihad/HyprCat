#!/bin/bash

# Define thresholds matching your Waybar states
LOW=30
CRITICAL=15

# Get capacity and status from sysfs
PERCENT=$(cat /sys/class/power_supply/BAT0/capacity)
STATUS=$(cat /sys/class/power_supply/BAT0/status)

# File paths for state/notification tracking
STATE_FILE="/tmp/bat_state"
LOW_FLAG="/tmp/bat_low_notified"
CRIT_FLAG="/tmp/bat_crit_notified"
LOCK_FILE="/tmp/bat_lock_time"

# --- FIX: Use a file descriptor lock to prevent race conditions ---
exec 9>"$LOCK_FILE"
flock -x 9 # This forces other instances to wait right here until this one finishes

CURRENT_TIME=$(date +%s)

if [ -f "$LOCK_FILE" ]; then
    LAST_TIME=$(cat "$LOCK_FILE")
else
    LAST_TIME=0
fi

TIME_DIFF=$((CURRENT_TIME - LAST_TIME))

# Only process plug/unplug if at least 3 seconds have passed
if [ "$TIME_DIFF" -ge 3 ]; then
    if [ -f "$STATE_FILE" ]; then
        PREV_STATUS=$(cat "$STATE_FILE")
        
        if [ "$STATUS" = "Charging" ] && [ "$PREV_STATUS" != "Charging" ]; then
            notify-send -u normal -t 2000 "󰂄 Charger Connected" "Battery is charging at ${PERCENT}%."
            echo "$CURRENT_TIME" > "$LOCK_FILE"
        elif [ "$STATUS" = "Discharging" ] && [ "$PREV_STATUS" != "Discharging" ]; then
            notify-send -u normal -t 2000 "󰚥 Charger Disconnected" "Running on battery power (${PERCENT}%)."
            echo "$CURRENT_TIME" > "$LOCK_FILE"
        fi
    fi
fi

# Always update the true status for the next cycle
echo "$STATUS" > "$STATE_FILE"

# Release the lock
flock -u 9

# --- LOW/CRITICAL BATTERY NOTIFICATIONS ---
if [ "$STATUS" = "Discharging" ]; then
    if [ "$PERCENT" -le "$CRITICAL" ]; then
        if [ ! -f "$CRIT_FLAG" ]; then
            notify-send -u critical "CRITICAL BATTERY" "Plug in charger immediately! Battery is at ${PERCENT}%."
            touch "$CRIT_FLAG"
        fi
    elif [ "$PERCENT" -le "$LOW" ]; then
        if [ ! -f "$LOW_FLAG" ]; then
            notify-send -u normal "Low Battery" "Battery is dropping. Currently at ${PERCENT}%."
            touch "$LOW_FLAG"
        fi
    fi
else
    # If charging or full, clear low battery notification flags
    rm -f "$LOW_FLAG" "$CRIT_FLAG"
fi