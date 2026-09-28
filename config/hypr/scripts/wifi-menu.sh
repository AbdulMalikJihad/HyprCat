#!/usr/bin/env bash

THEME="$HOME/.config/rofi/wifi.rasi"

RESCAN_LABEL="󰑓  Rescan for networks"

# 2. Get Wi-Fi list with Signal Strength & Security
# Emits: display_label \t raw_ssid \t security \t is_connected  (tab-separated)
# Dedupe by SSID (keeping the strongest signal seen for it), then sort so the
# connected network is always first, and everything else is strongest-to-weakest.
get_wifi_list() {
    local active_wifi
    active_wifi=$(nmcli -t -f "ACTIVE,SSID" device wifi list | grep "^yes" | cut -d':' -f2-)

    nmcli -t -f "ACTIVE,SSID,SIGNAL,SECURITY" device wifi list | grep -v "^:" | awk -F: -v active="$active_wifi" '
        NF>=3 {
            ssid=$2;
            signal=$3+0;
            sec=$4;

            if (ssid == "") next;

            # Keep only the strongest reading per SSID
            if (!(ssid in best_signal) || signal > best_signal[ssid]) {
                best_signal[ssid] = signal;
                best_sec[ssid] = sec;
            }
            if (ssid == active) is_conn[ssid] = 1;
        }
        END {
            for (s in best_signal) {
                signal = best_signal[s];
                sec = best_sec[s];
                conn = (s in is_conn) ? 1 : 0;

                if (signal > 80) bars="󰤨 ";
                else if (signal > 60) bars="󰤥 ";
                else if (signal > 40) bars="󰤢 ";
                else if (signal > 20) bars="󰤟 ";
                else bars="󰤯 ";

                label = sprintf("%s %3s%%  %-12s %s", bars, signal, sec, s);
                if (conn) label = label " (Connected 🟢)";

                # Sort key: connected network always wins, then by signal desc
                key = conn * 100000 + signal;
                printf "%d\t%s\t%s\t%s\t%d\n", key, label, s, sec, conn;
            }
        }
    ' | sort -t"$(printf '\t')" -k1,1 -rn | cut -f2-
}

# 2b. Show the menu, with a tappable Rescan entry pinned to the top.
# We ask rofi for the selected *index* (-format i) rather than the selected
# text, and look up the real SSID/security from parallel arrays. This is
# what makes the parsing safe even when the SSID or the security field
# (e.g. "WPA2 WPA3") itself contains a space — no more slicing it back out
# of the formatted display string.
while true; do
    mapfile -t wifi_rows < <(get_wifi_list)

    display_arr=("$RESCAN_LABEL")
    ssid_arr=("")
    sec_arr=("")

    for row in "${wifi_rows[@]}"; do
        IFS=$'\t' read -r disp rssid rsec _conn <<< "$row"
        display_arr+=("$disp")
        ssid_arr+=("$rssid")
        sec_arr+=("$rsec")
    done

    selected_index=$(printf '%s\n' "${display_arr[@]}" | rofi -dmenu -p "Wi-Fi" -theme "$THEME" -format i)

    if [ -z "$selected_index" ]; then exit 0; fi

    if [ "$selected_index" -eq 0 ]; then
        # Trigger an actual rescan and give NetworkManager a few seconds to
        # populate results before re-reading the list — nmcli's rescan call
        # returns immediately even though the scan itself takes time.
        nmcli device wifi rescan >/dev/null 2>&1
        sleep 3
        continue
    fi

    ssid="${ssid_arr[$selected_index]}"
    sec="${sec_arr[$selected_index]}"
    break
done

# 3. Action selection submenu (ssid/sec were resolved directly from the
# menu selection above — no re-parsing of display text needed)
opts="Connect\nDisconnect\nForget Network"
chosen_action=$(echo -e "$opts" | rofi -dmenu -p "Action ($ssid)" -theme "$THEME")

# Show a result message: prefer a non-blocking desktop notification, fall
# back to a rofi dialog if notify-send isn't installed.
show_result() {
    local title="$1" body="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body"
    else
        rofi -theme "$THEME" -e "$title: $body"
    fi
}

case "$chosen_action" in
    "Connect")
        saved_connections=$(nmcli -g NAME connection show)
        if echo "$saved_connections" | grep -wF "$ssid" > /dev/null; then
            result=$(nmcli connection up id "$ssid" 2>&1)
        else
            if [[ "$sec" == *WPA* || "$sec" == *WEP* ]]; then
                wifi_pass=$(rofi -dmenu -p "Password: " -password -theme "$THEME")
                if [ -z "$wifi_pass" ]; then exit 0; fi
                result=$(nmcli device wifi connect "$ssid" password "$wifi_pass" 2>&1)
            else
                result=$(nmcli device wifi connect "$ssid" 2>&1)
            fi
        fi
        status=$?
        if [ "$status" -eq 0 ]; then
            show_result "Wi-Fi" "Connected to $ssid"
        else
            show_result "Wi-Fi connection failed" "$result"
        fi
        ;;
    "Disconnect")
        wifi_device=$(nmcli -t -f DEVICE,TYPE device | grep ":wifi" | cut -d: -f1 | head -n1)
        result=$(nmcli device disconnect "$wifi_device" 2>&1)
        status=$?
        if [ "$status" -eq 0 ]; then
            show_result "Wi-Fi" "Disconnected"
        else
            show_result "Wi-Fi" "Disconnect failed: $result"
        fi
        ;;
    "Forget Network")
        result=$(nmcli connection delete id "$ssid" 2>&1)
        status=$?
        if [ "$status" -eq 0 ]; then
            show_result "Wi-Fi" "Forgot $ssid"
        else
            show_result "Wi-Fi" "Failed to forget $ssid: $result"
        fi
        ;;
esac