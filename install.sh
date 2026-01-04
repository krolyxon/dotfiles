#!/bin/env bash

log() {
    local level="$1"
    shift

    local color reset='\033[0m'
    case "$level" in
        INFO)    color='\033[0;34m' ;; # Blue
        WARN)    color='\033[0;33m' ;; # Yellow
        ERROR)   color='\033[0;31m' ;; # Red
        SUCCESS) color='\033[0;32m' ;; # Green
        *)       color='\033[0m' ;;
    esac

    printf '%b[%s] [%s]%b %s\n' \
        "$color" "$(date '+%H:%M:%S')" "$level" "$reset" "$*" >&2
}

# Prevent user from running this script as root
if [[ "$EUID" -eq 0 ]]; then
    log ERROR "This script must NOT be run as root."
    log INFO "If you need elevated privileges, the script will ask for sudo when required."
    exit 1
fi

currentDir="$(dirname "$(readlink -f "$0")")"
cd "$currentDir"

## Install necessary desktop packages
source "$currentDir/packages/pkg_desktop.sh"
source "$currentDir/packages/pkg_utils.sh"
log INFO "Starting Script"
log INFO "Installing necessary packages for hyprland"
sudo pacman -Sy --needed "${pkg_desktop[@]}" "${pkg_utils[@]}"

## Install dev tools
read -rp "Do you wish to install development tools? [y/N]" install_dev_tools
if [[ $install_dev_tools == y ]]; then
    log INFO "Installing development tools"
    source "$currentDir/packages/pkg_dev_tools.sh"
    sudo pacman -S --needed "${pkg_dev_tools[@]}"
fi

## Install optional packages
read -rp "Do you wish to install optional packages? [y/N]" install_optional_pkg
if [[ $install_optional_pkg == y ]]; then
    log INFO "Installing development tools"
    source "$currentDir/packages/pkg_optional.sh"
    sudo pacman -S --needed "${pkg_optional[@]}"
fi

## Install nvidia drivers
read -rp "Do you wish to install GPU drivers? (Intel & Nvidia) [y/N]" install_gpu_drivers
if [[ $install_gpu_drivers == y ]]; then
    log INFO "Installing GPU Drivers"
    source "$currentDir/packages/pkg_gpu.sh"
    sudo pacman -S --needed "${pkg_gpu[@]}"
fi


## Install aur packages
read -rp "Do you wish to install aur packages? [y/N]" install_aur_pkg
if [[ $install_aur_pkg == y ]]; then
    ## Install paru if it isn't already installed
    if ! command -v paru >/dev/null 2>&1; then
        log INFO "Installing Paru (AUR package manager)"
        git clone https://aur.archlinux.org/paru.git
        cd paru
        makepkg -sri
        cd ..
        rm -rf paru
    else
        log INFO "Skipping paru (already in PATH)"
    fi
    ## Install aur packages
    source "$currentDir/packages/pkg_aur.sh"
    paru -S --needed  "${pkg_aur[@]}"
fi


## Setup dotfiles
log WARN "This will DELETE any conflicting files and replace them with symlinks from this repo."
log WARN "Make sure you have already backed up all your existing config files (~/.config)"
read -rp "Continue with stow (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    log INFO "Detecting conflicts..."
    conflicts=$(stow . --no-folding -nv 2>&1 | \
        sed -n 's/.*existing target \(.*\) since neither.*/\1/p')

    if [[ -z "$conflicts" ]]; then
        log INFO "No conflicts. Running stow normally..."
        stow . --no-folding \
            && log SUCCESS "Dotfiles stowed successfully" \
            || log ERROR "Stow failed"
    else
        log WARN "These paths conflict and will be removed:"
        printf '  %s\n' $conflicts
        read -rp "Proceed with deleting these files? (y/N): " ok
        if [[ ! "$ok" =~ ^[Yy]$ ]]; then
            echo "Aborted."
        fi

    # Remove conflicts relative to $HOME
    for path in $conflicts; do
        rm -rf "$HOME/$path" && log INFO "Removed $HOME/$path"
    done

    log INFO "Running stow..."
    stow . --no-folding \
        && log INFO "✅ Dotfiles stowed with overwrite." \
        || log ERROR "Stow failed"
    fi
else
    log WARN "Aborted stow, the dotfiles are not synced"
fi


## Setup neovim dotfiles
read -rp "Setup neovim configuration as well? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    log INFO "Taking backup of neovim config (if already exists)"
    mv ~/.config/nvim{,.bak}
    mv ~/.local/share/nvim{,.bak}
    mv ~/.local/state/nvim{,.bak}
    mv ~/.cache/nvim{,.bak}
    git clone --depth=1 git@github.com:krolyxon/nvim.git ~/.config/nvim
fi

## Change default shell to zsh
log INFO "Changing the default shell to ZSH"
if [[ "$SHELL" != "$(which zsh)" ]]; then
    read -rp "Change default shell to ZSH? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        chsh -s $(which zsh) \
            && log SUCCESS "Default shell successfully set to zsh" \
            || log ERROR "Default shell could not be set to zsh"
    fi
else
    log INFO "Skipping: zsh is already the default shell"
fi


## Install and setup Keyd
read -rp "Configure and enable Keyd? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
       log INFO "Copying keyd configuration to /etc/keyd/default.conf"
       sudo cp "$currentDir/system/etc/keyd/default.conf" /etc/keyd/
       sudo systemctl enable --now keyd.service \
           && log SUCCESS "Successfully enabled keyd.service" \
           || log ERROR "Couldn't enable keyd.service"
fi



printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo ""
log SUCCESS "Done!"
