#!/usr/bin/env bash
#
# krolyxon's dotfiles installer
#
# READ THIS FIRST:
#   This sets up MY personal desktop (Arch + Hyprland + aurora), built around my own
#   hardware (Lenovo Legion, Intel + NVIDIA hybrid, linux-zen) and my habits.
#   It is NOT a general purpose installer and I'm not trying to make it one.
#
#   Only run it on a FRESHLY INSTALLED, UNCONFIGURED Arch Linux system.
#   It installs a lot of packages, moves your existing configs out of the way,
#   changes your login shell and can enable system services.
#
#   If you just want a piece of the setup, copy the files you like instead.
#
# Usage:
#   ./install.sh           interactive
#   ./install.sh --yes     pre-select everything (still asks the fresh-system question)
#   ./install.sh --check   compare installed packages with packages/*.txt, changes nothing

trap 'log WARN "Interrupted by user"; exit 130' INT

INSTALL_STATUS="none"   # none | partial | complete | failed
AUTO_YES=0
CHECK_ONLY=0
BACKUP_DIR=""

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

usage() {
    sed -n '3,19s/^# \{0,1\}//p' "$0"
}

#######################
## Arguement Parsing ##
#######################
for arg in "$@"; do
    case "$arg" in
        --yes|--ci|--non-interactive)
            AUTO_YES=1
            ;;
        --check)
            CHECK_ONLY=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log ERROR "Unknown option: $arg"
            usage
            exit 1
            ;;
    esac
done

currentDir="$(dirname "$(readlink -f "$0")")"
cd "$currentDir" || exit 1
PKG_DIR="$currentDir/packages"


###################
## Package lists ##
###################
# packages/*.txt: one package per line, '#' comments.
# A trailing '!' (e.g. "blender !") means: listed, but not pre-selected in the picker.

# All packages in a list
read_list() {
    sed 's/#.*//' "$PKG_DIR/$1.txt" | awk 'NF { print $1 }'
}

# Packages of a list that are pre-selected in the picker
preselected() {
    sed 's/#.*//' "$PKG_DIR/$1.txt" | awk 'NF && $2 != "!" { print $1 }'
}

check_packages() {
    local listed installed aur
    listed=$(for f in "$PKG_DIR"/*.txt; do read_list "$(basename "$f" .txt)"; done | sort -u)
    installed=$(pacman -Qqe | sort -u)
    aur=$(pacman -Qqm | sort -u)

    echo "Installed explicitly, but not in any packages/*.txt:"
    comm -23 <(echo "$installed") <(echo "$listed") | while read -r p; do
        if grep -qx "$p" <<< "$aur"; then echo "  $p (aur)"; else echo "  $p"; fi
    done

    echo
    echo "Listed, but not installed:"
    comm -13 <(pacman -Qq | sort -u) <(echo "$listed") | sed 's/^/  /'
}

if ((CHECK_ONLY)); then
    check_packages
    exit 0
fi


#################
## GATEKEEPING ##
#################

## Prevent user from running this script as root
if [[ "$EUID" -eq 0 ]]; then
    log ERROR "This script must NOT be run as root."
    log INFO "If you need elevated privileges, the script will ask for sudo when required."
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    log ERROR "This is not Arch Linux. These dotfiles and this script are for Arch only."
    exit 1
fi

## Does this look like a system that is already set up?
## (configs this repo doesn't provide, or another desktop's config)
check_fresh_system() {
    local foreign=() desktops=() entry
    for entry in "$HOME"/.config/*; do
        [[ -e "$entry" ]] || continue
        entry="$(basename "$entry")"
        [[ -e "$currentDir/.config/$entry" ]] || foreign+=("$entry")
    done
    for entry in i3 sway niri river awesome bspwm openbox qtile xfce4 \
                 kdeglobals plasma-org.kde.plasma.desktop-appletsrc gnome-session; do
        [[ -e "$HOME/.config/$entry" ]] && desktops+=("$entry")
    done

    ((${#foreign[@]} <= 10 && ${#desktops[@]} == 0)) && return 0

    printf '\033[1;31m'
    echo "=================================================================="
    echo " This does NOT look like a fresh Arch install."
    echo
    ((${#desktops[@]})) && echo " Found another desktop's config: ${desktops[*]}"
    ((${#foreign[@]} > 10)) && echo " Found ${#foreign[@]} entries in ~/.config that this repo doesn't provide."
    echo
    echo " This installer is meant for a freshly installed, unconfigured"
    echo " system. On a system you already use it WILL change things you"
    echo " care about: your configs get moved aside, your shell changes, and"
    echo " lots of packages get installed."
    echo "=================================================================="
    printf '\033[0m'
    local answer
    read -rp "Type 'I understand' to continue anyway: " answer
    [[ "$answer" == "I understand" ]] || { log WARN "Aborted."; exit 1; }
}
check_fresh_system

choose_packages() {
    local list="$1"
    gum choose --no-limit \
        --selected "$(preselected "$list" | paste -sd,)" \
        $(read_list "$list")
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

install_prerequisites() {
    sudo pacman -S --needed --noconfirm stow gum git zsh
}

## Installs prerequisites
log INFO "Installing prerequisites: "
install_prerequisites


DISCLAIMER=$(gum style \
  --border double \
  --border-foreground 196 \
  --padding "1 2" \
  --bold \
"⚠️  DISCLAIMER

These are MY personal dotfiles, built for MY machine
(Lenovo Legion, Intel + NVIDIA hybrid, linux-zen) and the way I work.
They are NOT general purpose. They're public as a reference,
or for people who want exactly the same setup.

Only run this on a FRESHLY INSTALLED, UNCONFIGURED Arch system.

This script is provided AS IS, WITHOUT ANY WARRANTY. It will:
• Install a lot of packages (including NVIDIA drivers if selected)
• Move conflicting files in your \$HOME to ~/.dotfiles-backup/
• Change your login shell to zsh
• Optionally write /etc/keyd and enable keyd
• Enable the aurora.service user unit

Proceed at your OWN RISK."
)

confirm "$DISCLAIMER

Do you understand the risks and want to continue?" || exit 1


#######################
## Package selection ##
#######################
SELECTED_PKGS=()
for list in utils dev gpu optional aur; do
    case "$list" in
        utils)    prompt_style "Important utilities (Most likely go with defaults)" ;;
        dev)      prompt_style "Select Development Tools" ;;
        gpu)      prompt_style "Select GPU drivers" ;;
        optional) prompt_style "Select Optional Desktop Packages" ;;
        aur)      prompt_style "Select AUR packages" ;;
    esac

    if ((AUTO_YES)); then
        mapfile -t picked < <(preselected "$list")
    else
        gum_to_array picked < <(choose_packages "$list")
    fi
    SELECTED_PKGS+=("${picked[@]}")
done


##########################
## Configure Everything ##
##########################
WARNING=$(gum style \
  --border double \
  --border-foreground 196 \
  --padding "1 2" \
  --bold \
  "⚠️  Files in your \$HOME that conflict with this repo will be MOVED to
~/.dotfiles-backup/<date>/ and replaced with symlinks from this repo.")

if confirm "$WARNING

Proceed with system configuration (stow, shell)?"; then
    ###################
    ## Stow dotfiles ##
    ###################
    log INFO "Detecting conflicts..."
    mapfile -t conflicts < <(stow . --no-folding -nv 2>&1 | \
        sed -n 's/.*existing target \(.*\) since neither.*/\1/p')

    if ((${#conflicts[@]} == 0)); then
        log INFO "No conflicts. Running stow normally..."
    else
        log WARN "These paths conflict and will be moved to a backup:"
        printf '  %s\n' "${conflicts[@]}"
        if ! confirm "Move these files to ~/.dotfiles-backup/ ?"; then
            log WARN "Aborted."
            exit 1
        fi

        # Move conflicts (relative to $HOME) into the backup dir, keeping their paths
        BACKUP_DIR="$HOME/.dotfiles-backup/$(date '+%Y%m%d-%H%M%S')"
        for path in "${conflicts[@]}"; do
            [[ -n "$path" && "$path" != "/" ]] || continue
            mkdir -p "$BACKUP_DIR/$(dirname "$path")"
            mv "$HOME/$path" "$BACKUP_DIR/$path" && log INFO "Backed up $path"
        done
        log INFO "Backups are in $BACKUP_DIR"
    fi

    stow . --no-folding \
        && log SUCCESS "Dotfiles stowed successfully" \
        || log ERROR "Stow failed"

    #################################
    ## Change default shell to zsh ##
    #################################
    log INFO "Changing the default shell to ZSH"
    if [[ "$SHELL" != "$(command -v zsh)" ]]; then
        chsh -s "$(command -v zsh)" \
            && log SUCCESS "Default shell successfully set to zsh" \
            || log ERROR "Default shell could not be set to zsh"
    else
        log INFO "Skipping: zsh is already the default shell"
    fi
else
    log ERROR "Aborted stow, didn't configure or install anything"
    exit 1
fi


mapfile -t DESKTOP_PKGS < <(read_list desktop)
ALL_PKGS=(
    "${DESKTOP_PKGS[@]}"
    "${SELECTED_PKGS[@]}"
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
            sudo pacman -S --needed --noconfirm base-devel
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


#########################
## Enable aurora shell ##
#########################
# User unit, stowed to ~/.config/systemd/user. Hyprland starts it at login,
# enabling it also ties it to graphical-session.target. No --now: no session yet.
if [[ -f "$HOME/.config/systemd/user/aurora.service" ]]; then
    if confirm "Enable aurora.service (the desktop shell)?"; then
        systemctl --user daemon-reload
        systemctl --user enable aurora.service \
            && log SUCCESS "Successfully enabled aurora.service" \
            || log ERROR "Couldn't enable aurora.service (run 'systemctl --user enable aurora' after logging in)"
    fi
else
    log WARN "aurora.service is not stowed, skipping"
fi


####################
## Final dialogue ##
####################
BACKUP_NOTE=""
[[ -n "$BACKUP_DIR" ]] && BACKUP_NOTE="

Your old conflicting files are in:
$BACKUP_DIR"

case "$INSTALL_STATUS" in
    complete)
        gum style \
          --border rounded \
          --border-foreground 42 \
          --padding "1 2" \
          --bold \
        "✔ Installation Complete!

All selected packages were installed successfully.
You may now reboot the system for all the changes to apply.$BACKUP_NOTE"
        ;;
    partial)
        gum style \
          --border rounded \
          --border-foreground 220 \
          --padding "1 2" \
          --bold \
        "⚠ Setup Finished (Partial)

Some steps were skipped by user choice.
Your system was NOT fully configured.$BACKUP_NOTE"
        ;;
    failed)
        gum style \
          --border rounded \
          --border-foreground 196 \
          --padding "1 2" \
          --bold \
        "❌ Installation Failed

One or more steps did not complete successfully.
Check the logs above.$BACKUP_NOTE"
        ;;
    *)
        gum style --bold "Finished.$BACKUP_NOTE"
        ;;
esac
