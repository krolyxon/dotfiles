#!/bin/env bash

currentDir="$(dirname "$(readlink -f "$0")")"
cd "$currentDir"

## Install necessary desktop packages
source "$currentDir/packages/pkg_desktop.sh"
source "$currentDir/packages/pkg_utils.sh"
sudo pacman -S --needed "${pkg_desktop[@]}" "${pkg_utils[@]}"

## Install dev tools
read -rp "Do you wish to install development tools? [y/N]" install_dev_tools
source "$currentDir/packages/pkg_dev_tools.sh"
if [[ $install_dev_tools == y ]]; then
    sudo pacman -S --needed "${pkg_dev_tools[@]}"
fi

## Install optional packages
read -rp "Do you wish to install optional packages? [y/N]" install_optional_pkg
if [[ $install_optional_pkg == y ]]; then
    source "$currentDir/packages/pkg_optional.sh"
    sudo pacman -S --needed "${pkg_optional[@]}"
fi

## Install nvidia drivers
read -rp "Do you wish to install Nvidia drivers? [y/N]" install_nvidia_drivers
if [[ $install_nvidia_drivers == y ]]; then
    source "$currentDir/packages/pkg_nvidia.sh"
    sudo pacman -S --needed "${pkg_nvidia[@]}"
fi


## Install aur packages
read -rp "Do you wish to install aur packages? [y/N]" install_aur_pkg
if [[ $install_aur_pkg == y ]]; then
    ## Install paru if it isn't already installed
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
    ## Install aur packages
    source "$currentDir/packages/pkg_aur.sh"
    paru -S --needed  "${pkg_aur[@]}"
fi


## Setup dotfiles
echo "⚠️  WARNING: This will DELETE any conflicting files and replace them with symlinks from this repo."
echo "Make sure you have already backed up all your existing config files (~/.config)"
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
    echo "Aborted stow"
fi


## Setup neovim dotfiles
read -rp "Clone neovim dotfiles as well? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Taking backup of neovim config (if already exists)"
    mv ~/.config/nvim{,.bak}
    mv ~/.local/share/nvim{,.bak}
    mv ~/.local/state/nvim{,.bak}
    mv ~/.cache/nvim{,.bak}
    git clone --depth=1 git@github.com:krolyxon/nvim.git ~/.config/nvim
fi

## Change default shell to zsh
if [[ "$SHELL" != "$(which zsh)" ]]; then
    read -rp "Change default shell to ZSH? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Changing default shell to zsh..."
        chsh -s $(which zsh)
    fi
else
    echo "Skipping: zsh is already the default shell"
fi


printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo ""
echo "Done! 😊"
