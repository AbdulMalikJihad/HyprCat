#!/usr/bin/env bash

# Exit immediately on error, unbound variable, or pipe failure
set -euo pipefail

# Define colors for output
GREEN="\e[32m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

log_info() { echo -e "${GREEN}[*] $1${ENDCOLOR}"; }
log_warn() { echo -e "${BLUE}[!] $1${ENDCOLOR}"; }

# 1. Update System & Core Dependencies
log_info "Updating system databases and installing core build dependencies..."
sudo pacman -Syu --needed --noconfirm base-devel git pacman-contrib pciutils curl wget

# 2. Install Yay (AUR Helper) if missing
if ! command -v yay &> /dev/null; then
    log_info "yay is not installed. Installing yay-bin..."
    BUILD_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$BUILD_DIR"
    (cd "$BUILD_DIR" && makepkg -si --noconfirm)
    rm -rf "$BUILD_DIR"
else
    log_info "yay is already installed."
fi

# 3. Detect NVIDIA GPU & Prepare Pacman Packages
PACMAN_PKGS=(
    "base" "base-devel" "bluez" "bluez-utils" "brightnessctl" "btop" 
    "btrfs-progs" "cliphist" "cmatrix" "cups" "cups-pk-helper" "efibootmgr" 
    "fastfetch" "git" "grim" "gst-plugin-pipewire" "hypridle" "hyprland" 
    "hyprlock" "intel-ucode" "kitty" "libpulse" "linux" "linux-firmware" "linux-headers"
    "mpv" "nano" "nautilus" "networkmanager" "noto-fonts" "noto-fonts-cjk" 
    "noto-fonts-emoji" "nwg-look" "pavucontrol" "pipewire" "pipewire-alsa" 
    "pipewire-jack" "pipewire-pulse" "power-profiles-daemon" "qt5-declarative" 
    "qt5-graphicaleffects" "qt5-quickcontrols" "qt5-quickcontrols2" "qt6-declarative" 
    "qt6-5compat" "rofi" "sddm" "slurp" "sudo" "swappy" "swaync" "system-config-printer" 
    "ttf-dejavu" "ttf-iosevka-nerd" "ttf-jetbrains-mono-nerd" "ttf-liberation" 
    "ttf-nerd-fonts-symbols-common" "ufw" "waybar" "wireplumber" "wl-clipboard" 
    "wpa_supplicant" "wtype" "zram-generator" "awww"
    "zsh" "zsh-completions"
)

# NVIDIA Detection
HAS_NVIDIA=false
if lspci | grep -Ei "vga|3d|display" | grep -qi "nvidia"; then
    HAS_NVIDIA=true
    log_info "NVIDIA GPU detected! Adding NVIDIA drivers and Wayland compatibility packages..."
    NVIDIA_PKGS=(
        "nvidia-dkms"
        "nvidia-utils"
        "lib32-nvidia-utils"
        "nvidia-settings"
        "egl-wayland"
        "libva-nvidia-driver"
    )
    PACMAN_PKGS+=("${NVIDIA_PKGS[@]}")
else
    log_info "No NVIDIA GPU detected. Skipping NVIDIA driver installation."
fi

log_info "Installing official pacman packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# Configure NVIDIA Kernel Modesetting for Hyprland
if [ "$HAS_NVIDIA" = true ]; then
    log_info "Configuring Kernel Modesetting for NVIDIA..."
    
    sudo mkdir -p /etc/modprobe.d
    echo "options nvidia-drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
    
    if [ -f /etc/mkinitcpio.conf ]; then
        log_info "Updating mkinitcpio initramfs..."
        sudo mkinitcpio -P || true
    fi
fi

# 4. AUR Packages
AUR_PKGS=(
    "peaclock"
    "redhat-fonts"
    "sddm-silent-theme"
    "visual-studio-code-bin"
    "zen-browser-bin"
)

log_info "Installing AUR packages..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# 5. Install Oh My Zsh & Plugins
log_info "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    # --unattended prevents oh-my-zsh installer from launching zsh during execution
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

log_info "Installing custom Oh My Zsh plugins..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Install zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# Install zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Configure plugins in .zshrc
if [ -f "$HOME/.zshrc" ]; then
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/g' "$HOME/.zshrc"
fi

# Set ZSH as Default Shell
ZSH_PATH=$(which zsh)
if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
    log_info "Setting Zsh as default shell for $USER..."
    sudo chsh -s "$ZSH_PATH" "$USER"
fi

# 6. Selective Colloid GTK Theme Installation
log_info "Installing ONLY Colloid-Green-Dark-Compact-Everforest theme..."
THEME_BUILD_DIR=$(mktemp -d)
git clone https://github.com/vinceliuice/Colloid-gtk-theme.git "$THEME_BUILD_DIR"
"$THEME_BUILD_DIR/install.sh" --theme green --color dark --compact --tweaks everforest
rm -rf "$THEME_BUILD_DIR"

# 7. Deploy Configuration Files
log_info "Deploying configuration files to ~/.config/..."
mkdir -p "$HOME/.config"

if [ -d "./config" ]; then
    cp -a ./config/. "$HOME/.config/"
    find "$HOME/.config" -type f -name "*.sh" -exec chmod +x {} +
    log_info "Configuration files deployed successfully."
else
    log_warn "'config' folder not found. Skipping config copy."
fi

# 8. Deploy Wallpapers & Set Default via awww
log_info "Deploying wallpapers to ~/Pictures/Wallpapers/..."
mkdir -p "$HOME/Pictures/Wallpapers"

if [ -d "./Wallpapers" ]; then
    cp -a ./Wallpapers/. "$HOME/Pictures/Wallpapers/"
    log_info "Wallpapers deployed successfully."
else
    log_warn "'Wallpapers' directory not found. Skipping wallpaper deployment."
fi

WALLPAPER_TARGET="$HOME/Pictures/Wallpapers/2.jpg"
if [ -f "$WALLPAPER_TARGET" ]; then
    log_info "Setting 2.jpg as default wallpaper for awww..."
    if command -v awww &> /dev/null && [ -n "${WAYLAND_DISPLAY:-}" ]; then
        awww init || true
        awww img "$WALLPAPER_TARGET"
    fi
    
    mkdir -p "$HOME/.config/hypr"
    cat > "$HOME/.config/hypr/set_wallpaper.sh" <<EOF
#!/usr/bin/env bash
if command -v awww &> /dev/null; then
    awww init || true
    awww img "$HOME/Pictures/Wallpapers/2.jpg"
fi
EOF
    chmod +x "$HOME/.config/hypr/set_wallpaper.sh"
else
    log_warn "2.jpg not found in ~/Pictures/Wallpapers/. Skipped setting initial wallpaper."
fi

# 9. Set Colloid-Green-Dark-Compact-Everforest as Default System Theme
log_info "Applying default GTK 3.0, 4.0, and gsettings configuration..."

THEME_NAME="Colloid-Green-Dark-Compact-Everforest"

mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=${THEME_NAME}
gtk-icon-theme-name=${THEME_NAME}
gtk-font-name=Adwaita Sans Regular 11
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
EOF

mkdir -p "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-4.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=${THEME_NAME}
gtk-icon-theme-name=${THEME_NAME}
gtk-font-name=Adwaita Sans Regular 11
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
EOF

if command -v gsettings &> /dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
fi

# 10. Configure SDDM Theme & Permissions
SDDM_THEME_DIR="/usr/share/sddm/themes/sddm-silent-theme"

if [ -d "$SDDM_THEME_DIR" ]; then
    log_info "Applying sddm-silent-theme configuration..."
    sudo chmod -R 755 "$SDDM_THEME_DIR"
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<EOF
[Theme]
Current=sddm-silent-theme
EOF
else
    log_warn "sddm-silent-theme directory not found at $SDDM_THEME_DIR. Skipping SDDM config."
fi

# 11. Configure Kitty Terminal Theme
log_info "Applying Everforest theme to Kitty..."
mkdir -p "$HOME/.config/kitty"

cat > "$HOME/.config/kitty/theme.conf" << 'EOF'
# Everforest Dark Hard theme for Kitty
background            #2b3339
foreground            #d3c6aa

color0                #4b565c
color8                #4b565c
color1                #e67e80
color9                #e67e80
color2                #a7c080
color10               #a7c080
color3                #dbbc7f
color11               #dbbc7f
color4                #7fbbb3
color12               #7fbbb3
color5                #d699b6
color13               #d699b6
color6                #83c092
color14               #83c092
color7                #d3c6aa
color15               #d3c6aa

cursor                #d3c6aa
cursor_text_color     #2b3339

selection_background  #3a444a
selection_foreground  #d3c6aa
EOF

if [ -f "$HOME/.config/kitty/kitty.conf" ]; then
    grep -qX "include theme.conf" "$HOME/.config/kitty/kitty.conf" || echo "include theme.conf" >> "$HOME/.config/kitty/kitty.conf"
else
    echo "include theme.conf" > "$HOME/.config/kitty/kitty.conf"
fi

# 12. Enable System Services
log_info "Enabling system services..."
SERVICES=(sddm NetworkManager bluetooth cups power-profiles-daemon)

for service in "${SERVICES[@]}"; do
    sudo systemctl enable "$service.service" 2>/dev/null || true
done

log_info "Installation and configuration complete!"
log_warn "Please restart your system to apply all changes."