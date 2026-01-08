#!/usr/bin/env bash

trap 'log WARN "Interrupted by user"; exit 130' INT

INSTALL_STATUS="none"   # none | partial | complete | failed
AUTO_YES=0

for arg in "$@"; do
    case "$arg" in
        --yes|--ci|--non-interactive)
            AUTO_YES=1
            ;;
    esac
done

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
    gum style \
        --border rounded \
        --padding "0 1" \
        "$1"
}

gum_warn(){
    gum style --bold --foreground 196 "⚠ $1"
}

gum_to_array() {
    local -n arr="$1"
    mapfile -t arr
    local cleaned=()
    for item in "${arr[@]}"; do
        [[ -n "$item" ]] && cleaned+=("$item")
    done
    arr=("${cleaned[@]}")
}

confirm() {
    local msg="$1"
    if ((AUTO_YES)); then
        log INFO "[auto] $msg → yes"
        return 0
    fi
    gum confirm --default=false "$msg"
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

confirm "$DISCLAIMER

Do you understand the risks and want to continue?" || exit 1


###########
## UTILS ##
###########
source "$currentDir/packages/pkg_utils.sh"
prompt_style "Important utilities (Most likely go with defaults)"
if ((AUTO_YES)); then
    DEV_PKGS=("${pkg_utils[@]}")
else
    gum_to_array UTILITY_PKGS < <(choose_packages pkg_utils)
fi


###############
## DEV TOOLS ##
###############
source "$currentDir/packages/pkg_dev_tools.sh"
prompt_style "Select Development Tools"
if ((AUTO_YES)); then
    DEV_PKGS=("${pkg_dev_tools[@]}")
else
    gum_to_array DEV_PKGS < <(choose_packages pkg_dev_tools)
fi



#######################
## OPTIONAL PACKAGES ##
#######################
source "$currentDir/packages/pkg_optional.sh"
prompt_style "Select Optional Desktop Packages"
if ((AUTO_YES)); then
    OPTIONAL_PKGS=("${pkg_optional[@]}")
else
    gum_to_array OPTIONAL_PKGS < <(choose_packages pkg_optional)
fi



#################
## GPU DRIVERS ##
#################
source "$currentDir/packages/pkg_gpu.sh"
prompt_style "Select GPU drivers"
if ((AUTO_YES)); then
    GPU_PKGS=("${pkg_gpu[@]}")
else
    gum_to_array GPU_PKGS < <(choose_packages pkg_gpu)
fi


##################
## AUR PACKAGES ##
##################
source "$currentDir/packages/pkg_aur.sh"
prompt_style "Select AUR packages"

if ((AUTO_YES)); then
    AUR_PKGS=("${pkg_aur[@]}")
else
    gum_to_array AUR_PKGS < <(choose_packages pkg_aur)
fi



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

if confirm "$WARNING

Proceed with system configuration (stow, shell)?"; then
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
            log  WARN "Aborted."
            exit 1
        fi

    # Remove conflicts relative to $HOME
    for path in $conflicts; do
        [[ -n "$path" && "$path" != "/" ]] && rm -rf "$HOME/$path" && log INFO "Deleted $path"
    done

    log INFO "Running stow..."
    stow . --no-folding \
        && log INFO "✅ Dotfiles stowed with overwrite." \
        || log ERROR "Stow failed"
    fi

    #################################
    ## Change default shell to zsh ##
    #################################
    log INFO "Changing the default shell to ZSH"
    if [[ "$SHELL" != "$(command -v zsh)" ]]; then
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



source "$currentDir/packages/pkg_desktop.sh"
ALL_PKGS=(
    "${DEV_PKGS[@]}"
    "${OPTIONAL_PKGS[@]}"
    "${GPU_PKGS[@]}"
    "${UTILITY_PKGS[@]}"
    "${AUR_PKGS[@]}"
    "${pkg_desktop[@]}"
)

########################
## Install Everything ##
########################
if ((${#ALL_PKGS[@]})); then
    if confirm "Install all the selected packages?"; then
        log INFO "Installing selected packages..."

        ## Installing paru if not installed already
        if ! command -v paru >/dev/null 2>&1; then
            log INFO "Installing Paru (AUR package manager)"
            git clone https://aur.archlinux.org/paru.git
            (cd paru && makepkg -sri)
            rm -rf paru
        fi

        if paru -Syu --needed "${ALL_PKGS[@]}"; then
            INSTALL_STATUS="complete"
        else
            INSTALL_STATUS="failed"
        fi
    else
        log WARN "Package installation skipped by user"
        INSTALL_STATUS="partial"
    fi
else
    log WARN "No packages selected"
    INSTALL_STATUS="partial"
fi



################
## Setup Keyd ##
################
if command -v keyd >/dev/null 2>&1; then
    if confirm "Configure and enable keyd? "; then
        log INFO "Copying keyd configuration to /etc/keyd/default.conf"
        sudo cp "$currentDir/system/etc/keyd/default.conf" /etc/keyd/
        sudo systemctl enable --now keyd.service \
            && log SUCCESS "Successfully enabled keyd.service" \
            || log ERROR "Couldn't enable keyd.service"
    fi
fi


####################
## Final dialogue ##
####################
case "$INSTALL_STATUS" in
    complete)
        gum style \
          --border rounded \
          --border-foreground 42 \
          --padding "1 2" \
          --bold \
        "✔ Installation Complete!

All selected packages were installed successfully.
You may now reboot the system for all the changes to apply."
        ;;
    partial)
        gum style \
          --border rounded \
          --border-foreground 220 \
          --padding "1 2" \
          --bold \
        "⚠ Setup Finished (Partial)

Some steps were skipped by user choice.
Your system was NOT fully configured."
        ;;
    failed)
        gum style \
          --border rounded \
          --border-foreground 196 \
          --padding "1 2" \
          --bold \
        "❌ Installation Failed

One or more steps did not complete successfully.
Check the logs above."
        ;;
    *)
        gum style --bold "Finished."
        ;;
esac
