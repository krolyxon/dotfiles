#!/bin/env bash

pkg_utils=(
    "fd"
    "ffmpegthumbnailer"
    "foot"
    "fuzzel"
    "fzf"
    "gammastep"
    "ghostscript"
    "gobject-introspection"
    "gparted"
    "grub"
    "gvfs"
    "gvfs-mtp"
    "imagemagick"
    "imlib2"
    "jq"
    "kanshi"
    "lf"
    "libnotify"
    "libreoffice-fresh"
    "lua"
    "lvm2"
    "man-db"
    "meson"
    "mpc"
    "mpd"
    "mpd-mpris"
    "mpv"
    "ncdu"
    "ncmpcpp"
    "ntfs-3g"
    "nwg-look"
    "pacman-contrib"
    "pamixer"
    "pavucontrol"
    "pcmanfm"
    "pipewire"
    "pipewire-pulse"
    "progress"
    "python-gobject"
    "python-pip"
    "python-virtualenv"
    "qpdf"
    "reflector"
    "ripgrep"
    "rsync"
    "sshfs"
    "stow"
    "tesseract"
    "torbrowser-launcher"
    "transmission-cli"
    "noto-fonts"
    "noto-fonts-cjk"
    "noto-fonts-emoji"
    "ttf-jetbrains-mono-nerd"
    "tree"
    "unzip"
    "waybar"
    "wget"
    "woff2-font-awesome"
    "wtype"
    "xarchiver"
    "xdg-user-dirs"
    "yt-dlp"
    "zathura"
    "zathura-pdf-mupdf"
    "zip"
    "zola"
    "zsh"
    "zsh-autosuggestions"
)

pkg_dev_tools=(
    "git"
    "neovim"
    "platformio-core"
    "tmux"
    "nodejs"
    "lazygit"
)

pkg_optional=(
    "keepassxc"
    "obsidian"
    "syncthing"
    "newsboat"
    "obs-studio"
    "telegram-desktop"
)

pkg_nvidia=(
    "nvidia"
    "nvidia-utils"
)

pkg_desktop=(
    "hypridle"
    "hyprland"
    "hyprlock"
    "hyprpaper"
    "hyprpicker"
    "hyprpolkitagent"
    "hyprshot"
    "xdg-desktop-portal-hyprland"
    "swaync"
    "waybar"
)

pkg_aur=(
    "envycontrol"
    "htop-vim"
    "jmtpfs"
    "keepmenu"
    "keyd-git"
    "librewolf-bin"
    "python-pywal16"
    "tokyonight-gtk-theme-git"
    "zsh-fast-syntax-highlighting-git"
)


# Install necessary desktop packages
sudo pacman -S --needed "${pkg_desktop[@]}" "${pkg_utils[@]}"

# Install dev tools
read -rp "Do you wish to development tools? [y/n]" install_dev_tools
if [[ $install_dev_tools == y ]]; then
    sudo pacman -S --needed "${pkg_dev_tools[@]}"
fi

# Install optional packages
read -rp "Do you wish to install optional packages? [y/n]" install_optional_pkg
if [[ $install_optional_pkg == y ]]; then
    sudo pacman -S --needed "${pkg_optional[@]}"
fi

# Install nvidia drivers
read -rp "Do you wish to install Nvidia drivers? [y/n]" install_nvidia_drivers
if [[ $install_nvidia_drivers == y ]]; then
    sudo pacman -S --needed "${pkg_nvidia[@]}"
fi


# Install aur packages
read -rp "Do you wish to aur packages? [y/n]" install_aur_pkg
# Install paru if it isn't already installed
if [[ $install_aur_pkg == y ]]; then
    if ! command -v paru >/dev/null 2>&1; then
        echo "Installing paru..."
        git clone https://aur.archlinux.org/paru-bin.git
        cd paru-bin
        makepkg -sri
        cd ..
        rm -rf paru-bin
    else
        echo "Skipping paru (already in PATH)"
    fi
# Install aur packages
paru -S --needed  "${pkg_aur[@]}"
fi


# Setup dotfiles
echo "⚠️  WARNING: This will DELETE any conflicting files and replace them with symlinks from this repo."
echo "   Make sure your dotfiles repo is the source of truth / already backed up."
read -rp "Continue with stow (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Detecting conflicts..."
    conflicts=$(stow . --no-folding -nv 2>&1 | \
        sed -n 's/.*existing target \(.*\) since neither.*/\1/p')

    if [[ -z "$conflicts" ]]; then
        echo "No conflicts. Running stow normally..."
        stow . --no-folding
        echo "✅ Done."
    else
        echo "These paths conflict and will be removed:"
        printf '  %s\n' $conflicts
        read -rp "Proceed with deleting these files? (y/N): " ok
        if [[ ! "$ok" =~ ^[Yy]$ ]]; then
            echo "Aborted."
        fi

    # Remove conflicts relative to $HOME
    for path in $conflicts; do
        echo "Removing $HOME/$path"
        rm -rf "$HOME/$path"
    done

    echo "Running stow..."
    stow . --no-folding
    echo "✅ Dotfiles stowed with overwrite."
    fi
else
    echo "Aborted"
fi
