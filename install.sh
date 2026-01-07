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


## Prevent user from running this script as root
if [[ "$EUID" -eq 0 ]]; then
    log ERROR "This script must NOT be run as root."
    log INFO "If you need elevated privileges, the script will ask for sudo when required."
    exit 1
fi


## Check if gum is installed
if ! command -v gum >/dev/null 2>&1; then
    echo "gum is required. Install it first."
    exit 1
fi

## Check if git is installed
if ! command -v git >/dev/null 2>&1; then
    echo "git is required. Install it first."
    exit 1
fi


currentDir="$(dirname "$(readlink -f "$0")")"
cd "$currentDir"


choose_packages() {
    local -n arr=$1
    gum choose --no-limit \
        --selected "$(IFS=,; echo "${arr[*]}")" \
        "${arr[@]}"
}

prompt_style() {
    gum style --border rounded \
    --border double \
    --padding "0 1" \
    "$1"
}

gum_warn(){
    gum style --bold --foreground 196 "⚠ $1"
}

gum_to_array() {
    mapfile -t "$1"
}

#################
## GATEKEEPING ##
#################

DISCLAIMER=$(gum style \
  --border double \
  --border-foreground 196 \
  --padding "1 2" \
  --bold \
"⚠️  DISCLAIMER

This script is provided AS IS, WITHOUT ANY WARRANTY.
There is NO guarantee that it will work on your system.

It may:
• Modify system files
• Overwrite or DELETE existing configuration
• Potentially break your setup

You are STRONGLY ADVISED to back up:
• ~/.config
• ~/.local
• /etc (if modified)

Proceed at your OWN RISK."
)

gum confirm --default=false "$DISCLAIMER

Do you understand the risks and want to continue?" || exit 1


###########
## UTILS ##
###########
source "$currentDir/packages/pkg_utils.sh"
prompt_style "Important utilities (Most likely go with defaults)"
gum_to_array UTILITY_PKGS < <(choose_packages pkg_utils)


###############
## DEV TOOLS ##
###############
source "$currentDir/packages/pkg_dev_tools.sh"
prompt_style "Select Development Tools"
gum_to_array DEV_PKGS < <(choose_packages pkg_dev_tools)


#######################
## OPTIONAL PACKAGES ##
#######################
source "$currentDir/packages/pkg_optional.sh"
prompt_style "Select Optional Desktop Packages"
gum_to_array OPTIONAL_PKGS < <(choose_packages pkg_optional)


#################
## GPU DRIVERS ##
#################
source "$currentDir/packages/pkg_gpu.sh"
prompt_style "Select GPU drivers"
gum_to_array GPU_PKGS < <(choose_packages pkg_gpu)

##########################
## Configure Everything ##
##########################
WARNING=$(gum style \
  --border double \
  --border-foreground 196 \
  --padding "1 2" \
  --bold \
  "⚠️  This will DELETE any conflicting files and replace them with symlinks from this repo.
Make sure you have already backed up all your existing config files (~/.config)")

if gum confirm --default=false "$WARNING

Proceed with system configuration (stow, nvim, shell, keyd)?"; then
    ###################
    ## Stow dotfiles ##
    ###################
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

    ###########################
    ## Setup neovim dotfiles ##
    ###########################
    log INFO "Setting up neovim configuration"
    log INFO "Taking backup of neovim config (if already exists)"
    mv ~/.config/nvim{,.bak}
    mv ~/.local/share/nvim{,.bak}
    mv ~/.local/state/nvim{,.bak}
    mv ~/.cache/nvim{,.bak}
    git clone --depth=1 https://github.com/krolyxon/nvim.git ~/.config/nvim

    #################################
    ## Change default shell to zsh ##
    #################################
    log INFO "Changing the default shell to ZSH"
    if [[ "$SHELL" != "$(which zsh)" ]]; then
        chsh -s $(which zsh) \
            && log SUCCESS "Default shell successfully set to zsh" \
            || log ERROR "Default shell could not be set to zsh"
    else
        log INFO "Skipping: zsh is already the default shell"
    fi
else
    log WARN "Aborted configuration, didn't configure anything"
    exit 1
fi

##################
## AUR PACKAGES ##
##################
source "$currentDir/packages/pkg_aur.sh"
prompt_style "Select AUR packages"
gum_to_array AUR_PKGS < <(choose_packages pkg_aur)
if [[ ${#AUR_PKGS[@]} -eq 0 ]]; then
    log WARN "No AUR packages selected"
else
 if ! command -v paru >/dev/null 2>&1; then
        log INFO "Installing Paru (AUR package manager)"
        git clone https://aur.archlinux.org/paru.git
        cd paru
        makepkg -sri
        cd ..
        rm -rf paru
    else
        log INFO "Paru already in PATH, Skipping...."
    fi

    if [[ ${#AUR_PKGS[@]} -eq 0 ]]; then
        log WARN "No AUR packages selected, Skipping...."
    else
        paru -S --needed  "${AUR_PKGS[@]}"
    fi
fi


############################
## Setup Keyd ##
############################
if command -v keyd >/dev/null 2>&1; then
    if gum confirm --default=false "Configure and enable keyd? "; then
        log INFO "Copying keyd configuration to /etc/keyd/default.conf"
        sudo cp "$currentDir/system/etc/keyd/default.conf" /etc/keyd/
        sudo systemctl enable --now keyd.service \
            && log SUCCESS "Successfully enabled keyd.service" \
            || log ERROR "Couldn't enable keyd.service"
    fi
fi

########################
## Install Everything ##
########################
source "$currentDir/packages/pkg_desktop.sh"
ALL_PKGS=(
    "${DEV_PKGS[@]}"
    "${OPTIONAL_PKGS[@]}"
    "${GPU_PKGS[@]}"
    "${UTILITY_PKGS[@]}"
    "${pkg_desktop[@]}"
)

if [[ ${#ALL_PKGS[@]} -eq 0 ]]; then
    log WARN "No packages selected."
else
    if gum confirm --default=false "Install all the selected packages?"; then
        log INFO "Installing selected packages..."
        sudo pacman -Sy --needed "${ALL_PKGS[@]}"
    fi
fi


gum style \
  --border rounded \
  --padding "1 2" \
  --bold \
  --foreground 42 \
"🎉 Installation Complete!

Your system has been successfully configured.

You may now reboot the system for all the changes to apply."
