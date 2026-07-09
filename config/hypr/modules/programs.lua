local M = {}

M.terminal = "kitty"
M.fileManager = "nautils"
M.browser = "zen-browser"
M.menu_cmd = "pkill rofi || rofi -show drun"
M.wall_cmd = "~/.config/hypr/scripts/wallpaper-picker.sh"
M.power_cmd = "~/.config/hypr/scripts/powermenu.sh"
M.wifi_cmd = "~/.config/hypr/scripts/wifi-menu.sh"
M.screenshot_cmd = "~/.config/hypr/scripts/screenshot.sh"
M.clipboard_cmd = "~/.config/hypr/scripts/clipboard-picker.sh"
M.bluetooth_cmd = "~/.config/hypr/scripts/bluetooth-menu.sh"

return M
