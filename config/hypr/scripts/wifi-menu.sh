#!/usr/bin/env bash

THEME="/home/jihad/.config/rofi/wifi.rasi"

# Fetch Wi-Fi networks clean and simple
wifi_list=$(nmcli -t -f "SECURITY,SSID" device wifi list | grep -v "^:" | awk -F: '{printf "%-15s %s\n", $1, $2}')

chosen_network=$(echo "$wifi_list" | uniq | rofi -dmenu -p "Wi-Fi" -theme "$THEME")

if [ -z "$chosen_network" ]; then
    exit 0
fi

# Extract clean SSID name
ssid=$(echo "$chosen_network" | awk '{$1=""; print $0}' | sed 's/^[ \t]*//')

saved_connections=$(nmcli -g NAME connection show)

if echo "$saved_connections" | grep -wF "$ssid" > /dev/null; then
    nmcli connection up id "$ssid"
else
    if [[ "$chosen_network" =~ "WPA" || "$chosen_network" =~ "WEP" ]]; then
        wifi_pass=$(rofi -dmenu -p "Password: " -password -theme "$THEME")
        if [ -z "$wifi_pass" ]; then
            exit 0
        fi
        nmcli device wifi connect "$ssid" password "$wifi_pass"
    else
        nmcli device wifi connect "$ssid"
    fi
fi
#!/usr/bin/env bash

THEME="/home/jihad/.config/hypr/scripts/wifi.rasi"

# 1. Get current active Wi-Fi network
active_wifi=$(nmcli -t -f "ACTIVE,SSID" device wifi list | grep "^yes" | cut -d':' -f2)

# 2. Fetch network list and explicitly label the connected one
wifi_list=$(nmcli -t -f "SECURITY,SSID" device wifi list | grep -v "^:" | awk -F: -v active="$active_wifi" '
    {
        if ($2 == active) {
            printf "%-15s %s (Connected 🟢)\n", $1, $2
        } else {
            printf "%-15s %s\n", $1, $2
        }
    }
' | uniq)

chosen_network=$(echo "$wifi_list" | rofi -dmenu -p "Wi-Fi" -theme "$THEME")

if [ -z "$chosen_network" ]; then exit 0; fi

# Extract clean SSID name (removes the security tag and connected label)
ssid=$(echo "$chosen_network" | awk '{$1=""; print $0}' | sed 's/ (Connected 🟢)//' | sed 's/^[ \t]*//')

# 3. Submenu Actions
opts="Connect\nDisconnect\nForget Network"
chosen_action=$(echo -e "$opts" | rofi -dmenu -p "Action ($ssid)" -theme "$THEME")

case "$chosen_action" in
    "Connect")
        saved_connections=$(nmcli -g NAME connection show)
        if echo "$saved_connections" | grep -wF "$ssid" > /dev/null; then
            nmcli connection up id "$ssid"
        else
            if [[ "$chosen_network" =~ "WPA" || "$chosen_network" =~ "WEP" ]]; then
                wifi_pass=$(rofi -dmenu -p "Password: " -password -theme "$THEME")
                if [ -z "$wifi_pass" ]; then exit 0; fi
                nmcli device wifi connect "$ssid" password "$wifi_pass"
            else
                nmcli device wifi connect "$ssid"
            fi
        fi
        ;;
    "Disconnect")
        nmcli device disconnect wlan0 2>/dev/null || nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -n1)
        ;;
    "Forget Network")
        nmcli connection delete id "$ssid"
        ;;
esac