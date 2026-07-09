#!/usr/bin/env bash

THEME="/home/jihad/.config/rofi/bluetooth.rasi"

# Check if bluetooth power is turned on
if [ $(bluetoothctl show | grep "Powered: yes" | wc -l) -eq 0 ]; then
    boot_action=$(echo -e "Yes\nNo" | rofi -dmenu -p "Bluetooth is Off. Power On?" -theme "$THEME")
    if [ "$boot_action" == "Yes" ]; then
        bluetoothctl power on
        sleep 1
    else
        exit 0
    fi
fi

# 1. Fetch paired and nearby available devices
# This parses out the MAC address and Device Name clearly
devices=$(bluetoothctl devices | awk '{print substr($0, index($0,$3)) " | " $2}')

# Add explicit status flags (Connected / Paired) to the list items
device_list=""
while read -r line; do
    if [ -z "$line" ]; then continue; fi
    name=$(echo "$line" | cut -d'|' -f1 | sed 's/[ \t]*$//')
    mac=$(echo "$line" | cut -d'|' -f2 | sed 's/^[ \t]*//')
    
    # Check connection and paired flags
    info=$(bluetoothctl info "$mac")
    if echo "$info" | grep -q "Connected: yes"; then
        device_list+="$name (Connected 🔵) | $mac\n"
    elif echo "$info" | grep -q "Paired: yes"; then
        device_list+="$name (Paired 🟢) | $mac\n"
    else
        device_list+="$name | $mac\n"
    fi
done <<< "$devices"

# Append a manual Scan option at the top of the menu
menu_options="[ Scan Nearby Devices]\n$device_list"

chosen_entry=$(echo -e "$menu_options" | sed '/^$/d' | rofi -dmenu -p "Bluetooth" -theme "$THEME")

if [ -z "$chosen_entry" ]; then exit 0; fi

# Handle scanning routine
if [ "$chosen_entry" == "[ Scan Nearby Devices]" ]; then
    rofi -e "Scanning for 5 seconds... Please wait." &
    scan_pid=$!
    bluetoothctl --timeout 5 scan on > /dev/null 2>&1
    kill $scan_pid 2>/dev/null
    exec "$0" # Restart script to show newly discovered items
fi

# Extract Device Name and MAC address cleanly
dev_name=$(echo "$chosen_entry" | cut -d'|' -f1 | sed -E 's/ \(Connected 🔵\)//' | sed -E 's/ \(Paired 🟢\)//' | sed 's/[ \t]*$//')
dev_mac=$(echo "$chosen_entry" | cut -d'|' -f2 | sed 's/^[ \t]*//')

# 2. Submenu Actions
opts="Connect\nDisconnect\nPair Device\nForget Device"
chosen_action=$(echo -e "$opts" | rofi -dmenu -p "Action ($dev_name)" -theme "$THEME")

case "$chosen_action" in
    "Connect")
        bluetoothctl connect "$dev_mac"
        ;;
    "Disconnect")
        bluetoothctl disconnect "$dev_mac"
        ;;
    "Pair Device")
        bluetoothctl pair "$dev_mac"
        bluetoothctl trust "$dev_mac"
        ;;
    "Forget Device")
        bluetoothctl remove "$dev_mac"
        ;;
esac