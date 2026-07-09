#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define colors for output
GREEN="\e[32m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

# Install pacman-contrib if missing (required for checkupdates)
if ! command -v checkupdates &> /dev/null; then
    echo -e "${GREEN}[*] Installing pacman-contrib...${ENDCOLOR}"
    sudo pacman -S --needed --noconfirm pacman-contrib
fi

echo -e "${GREEN}[*] Checking for system updates...${ENDCOLOR}"
if checkupdates &> /dev/null; then
    echo -e "${BLUE}[*] Updates found. Installing now...${ENDCOLOR}"
    sudo pacman -Syu --noconfirm --needed
else
    echo -e "${GREEN}[*] System is already up to date.${ENDCOLOR}"
fi

# Check if yay is installed, if not, install yay-bin from AUR
if ! command -v yay &> /dev/null; then
    echo -e "${GREEN}[*] yay is not installed. Installing yay-bin...${ENDCOLOR}"
    sudo pacman -S --needed --noconfirm base-devel git
    mkdir -p /tmp/yay-build
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-build
    cd /tmp/yay-build
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay-build
else
    echo -e "${GREEN}[*] yay is already installed.${ENDCOLOR}"
fi

# Array of your pacman packages
PACMAN_PKGS=(
    "base" "base-devel" "bluez" "bluez-utils" "brightnessctl" "btop" 
    "btrfs-progs" "cliphist" "cmatrix" "cups" "cups-pk-helper" "efibootmgr" 
    "fastfetch" "git" "grim" "gst-plugin-pipewire" "hypridle" "hyprland" 
    "hyprlock" "intel-ucode" "kitty" "libpulse" "linux" "linux-firmware" 
    "mpv" "nano" "nautilus" "networkmanager" "noto-fonts" "noto-fonts-cjk" 
    "noto-fonts-emoji" "nwg-look" "pavucontrol" "pipewire" "pipewire-alsa" 
    "pipewire-jack" "pipewire-pulse" "power-profiles-daemon" "qt5-declarative" 
    "qt5-graphicaleffects" "qt5-quickcontrols" "qt5-quickcontrols2" "qt6-5compat" 
    "rofi" "sddm" "slurp" "sudo" "swappy" "swaync" "system-config-printer" 
    "ttf-dejavu" "ttf-iosevka-nerd" "ttf-jetbrains-mono-nerd" "ttf-liberation" 
    "ttf-nerd-fonts-symbols-common" "ufw" "waybar" "wireplumber" "wl-clipboard" 
    "wpa_supplicant" "wtype" "zram-generator" "awww"
)

# Array to hold uninstalled packages
TO_INSTALL=()

echo "Checking package installation status..."

# Loop through and find missing packages
for pkg in "${PACMAN_PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &> /dev/null; then
        TO_INSTALL+=("$pkg")
    fi
done

# Install only if there are missing packages
if [ ${#TO_INSTALL[@]} -ne 0 ]; then
    echo "Installing missing packages: ${TO_INSTALL[*]}"
    sudo pacman -S --needed --noconfirm "${TO_INSTALL[@]}"
else
    echo "All pacman packages are already installed."
fi

# Array of your AUR packages
AUR_PKGS=(
    "colloid-everforest-gtk-theme-git"
    "peaclock"
    "redhat-fonts"
    "sddm-silent-theme"
    "visual-studio-code-bin"
    "zen-browser-bin"
)

# Array to hold uninstalled AUR packages
AUR_TO_INSTALL=()

echo "Checking AUR package installation status..."

# Loop through and find missing AUR packages
for pkg in "${AUR_PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &> /dev/null; then
        AUR_TO_INSTALL+=("$pkg")
    fi
done

# Install only if there are missing AUR packages
if [ ${#AUR_TO_INSTALL[@]} -ne 0 ]; then
    echo "Installing missing AUR packages: ${AUR_TO_INSTALL[*]}"
    yay -S --needed --noconfirm "${AUR_TO_INSTALL[@]}"
else
    echo "All AUR packages are already installed."
fi

# Append to the end of your script

echo -e "${GREEN}[*] Copying configuration files to ~/.config/...${ENDCOLOR}"

# Ensure the target configuration directory exists
mkdir -p "$HOME/.config"

# Check if your local config folder exists before copying
if [ -d "./config" ]; then
    # -p preserves existing executable permissions during copy
    cp -rvp ./config/* "$HOME/.config/"
    
    echo -e "${GREEN}[*] Making sure all deployed .sh files are executable...${ENDCOLOR}"
    # Automatically finds and marks all .sh files in ~/.config as executable
    find "$HOME/.config" -type f -name "*.sh" -exec chmod +x {} +
    
    echo -e "${GREEN}[*] Configuration files deployed successfully.${ENDCOLOR}"
else
    echo -e "${BLUE}[!] 'config' folder not found in the script directory. Skipping config copy.${ENDCOLOR}"
fi

# Append to the end of your script (Before system services)

echo -e "${GREEN}[*] Deploying wallpapers to ~/Pictures/Wallpapers/...${ENDCOLOR}"

# Ensure the target directory exists
mkdir -p "$HOME/Pictures/Wallpapers"

# Check if Wallpapers folder exists in script directory
if [ -d "./Wallpapers" ]; then
    # Copy all wallpapers over
    cp -rvp ./Wallpapers/* "$HOME/Pictures/Wallpapers/"
    
    # Initialize awww and set a default wallpaper if running inside a Wayland session
    if command -v awww &> /dev/null && [ -n "$WAYLAND_DISPLAY" ]; then
        echo -e "${GREEN}[*] Setting wallpaper with awww...${ENDCOLOR}"
        awww init || true
        # Dynamically grabs the first available image file in the directory to set as wallpaper
        FIRST_WALLPAPER=$(find "$HOME/Pictures/Wallpapers" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) | head -n 1)
        if [ -n "$FIRST_WALLPAPER" ]; then
            awww img "$FIRST_WALLPAPER"
        fi
    fi
    echo -e "${GREEN}[*] Wallpapers deployed successfully.${ENDCOLOR}"
else
    echo -e "${BLUE}[!] 'Wallpapers' folder not found in the script directory. Skipping.${ENDCOLOR}"
fi

# Append after the Wallpapers section, before system services

echo -e "${GREEN}[*] Activating GTK and SDDM themes...${ENDCOLOR}"

# 1. Configure GTK 3.0 theme via settings.ini (so nwg-look recognizes it instantly)
echo -e "${GREEN}[*] Setting GTK theme in settings.ini...${ENDCOLOR}"
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=Colloid-Green-Dark-Compact-Everforest
gtk-icon-theme-name=Colloid-Green-Dark-Compact-Everforest
gtk-font-name=Adwaita Sans Regular 11
gtk-cursor-theme-name=Adwaita
EOF


# Apply via gsettings as a fallback for GNOME/GTK4 applications
if command -v gsettings &> /dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme "Colloid-Green-Dark-Compact-Everforest" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Colloid-Green-Dark-Compact-Everforest" 2>/dev/null || true
fi

# 2. Configure SDDM to use the sddm-silent-theme [cite: 1, 2]
if [ -d "/usr/share/sddm/themes/sddm-silent-theme" ]; then
    echo -e "${GREEN}[*] Applying sddm-silent-theme configuration...${ENDCOLOR}"
    sudo mkdir -p /etc/sddm.conf.d
    
    sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<EOF
[Theme]
Current=sddm-silent-theme
EOF
else
    echo -e "${BLUE}[!] sddm-silent-theme not found in system directories. Skipping SDDM config.${ENDCOLOR}"
fi

# Append inside the Theme Activation block

# 3. Configure Kitty to use the Everforest Dark theme
echo -e "${GREEN}[*] Applying Everforest theme to Kitty...${ENDCOLOR}"
mkdir -p "$HOME/.config/kitty"

# Fetch or write the Everforest theme configuration for Kitty
cat > "$HOME/.config/kitty/theme.conf" << 'EOF'
# Everforest Dark Hard theme for Kitty
background            #2b3339
foreground            #d3c6aa

# Black
color0                #4b565c
color8                #4b565c

# Red
color1                #e67e80
color9                #e67e80

# Green
color2                #a7c080
color10               #a7c080

# Yellow
color3                #dbbc7f
color11               #dbbc7f

# Blue
color4                #7fbbb3
color12               #7fbbb3

# Magenta
color5                #d699b6
color13               #d699b6

# Cyan
color6                #83c092
color14               #83c092

# White
color7                #d3c6aa
color15               #d3c6aa

# Cursor
cursor                #d3c6aa
cursor_text_color     #2b3339

# Selection highlight
selection_background  #3a444a
selection_foreground  #d3c6aa
EOF

# Ensure kitty.conf includes the theme file if it doesn't already
if [ -f "$HOME/.config/kitty/kitty.conf" ]; then
    if ! grep -q "include theme.conf" "$HOME/.config/kitty/kitty.conf"; then
        echo "include theme.conf" >> "$HOME/.config/kitty/kitty.conf"
    fi
else
    echo "include theme.conf" > "$HOME/.config/kitty/kitty.conf"
fi

# Append to the end of your script

echo -e "${GREEN}[*] Enabling system services...${ENDCOLOR}"

# Enable SDDM (Display Manager) to boot into your login screen
if systemctl list-unit-files | grep -q sddm.service; then
    sudo systemctl enable sddm.service
fi

# Enable NetworkManager for internet connectivity
if systemctl list-unit-files | grep -q NetworkManager.service; then
    sudo systemctl enable NetworkManager.service
fi

# Enable Bluetooth service
if systemctl list-unit-files | grep -q bluetooth.service; then
    sudo systemctl enable bluetooth.service
fi

# Enable Cups service for printing
if systemctl list-unit-files | grep -q cups.service; then
    sudo systemctl enable cups.service
fi

# Enable Power Profiles Daemon for battery/power management
if systemctl list-unit-files | grep -q power-profiles-daemon.service; then
    sudo systemctl enable power-profiles-daemon.service
fi

echo -e "${GREEN}[=>] Installation and configuration complete!${ENDCOLOR}"
echo -e "${BLUE}[!] Please restart your system to boot into Hyprland.${ENDCOLOR}"

