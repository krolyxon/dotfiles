# Dotfiles

![aurora desktop](assets/aurora-desktop.webp)

My desktop: **Arch Linux + Hyprland** (Lua config) + **aurora**, a custom Quickshell shell (bar, panel,
notifications, OSD, dock), themed live from the wallpaper with **pywal16** and deployed with **GNU stow**.

## aurora
One shell instead of waybar, dunst, wlogout, fuzzel and a pile of scripts. Everything below is themed from the
current wallpaper.

<table>
  <tr>
    <td width="50%"><img src="assets/aurora-panel.webp" alt="control panel"><br>
      <sub><b>Control panel</b> · media, volume/mic/brightness, quick toggles, capture, session</sub></td>
    <td width="50%"><img src="assets/aurora-panel-sys.webp" alt="system tab"><br>
      <sub><b>System</b> · cpu, memory, disks, battery, power profile, GPU mode (envycontrol)</sub></td>
  </tr>
  <tr>
    <td><img src="assets/aurora-runner.webp" alt="runner"><br>
      <sub><b>Runner</b> (<kbd>Super</kbd>+<kbd>R</kbd>) · apps, scripts, calc, shell; also a dmenu for scripts</sub></td>
    <td><img src="assets/aurora-wallpicker.webp" alt="wallpaper picker"><br>
      <sub><b>Wallpaper picker</b> · folders, search, re-themes everything through pywal16</sub></td>
  </tr>
  <tr>
    <td><img src="assets/aurora-chars.webp" alt="glyph picker"><br>
      <sub><b>Glyph picker</b> (<kbd>Super</kbd>+<kbd>`</kbd>) · emoji, nerd icons, symbols, kaomoji, fancy text</sub></td>
    <td><img src="assets/aurora-power.webp" alt="power menu"><br>
      <sub><b>Power menu</b> (<kbd>Super</kbd>+<kbd>Esc</kbd>) · lock, logout, suspend, reboot, ...</sub></td>
  </tr>
  <tr>
    <td><img src="assets/aurora-cal.webp" alt="calendar"><br>
      <sub><b>Calendar</b> · from the clock in the bar</sub></td>
    <td><img src="assets/aurora-settings.webp" alt="settings app"><br>
      <sub><b>Settings</b> (<kbd>Super</kbd>+<kbd>I</kbd>) · network, sound, appearance, Hyprland, keybinds, display, power</sub></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/aurora-overview.webp" alt="overview"><br>
      <sub><b>Overview</b> · live previews of every workspace and window, click to jump</sub></td>
  </tr>
</table>

> [!WARNING]
> **This is my personal setup, not a general purpose dotfiles framework.**
>
> It's built around my hardware (Lenovo Legion, Intel + NVIDIA hybrid graphics, `linux-zen`), my monitors,
> my keyboard and my habits. I'm not trying to make it work for everyone, and I won't be adding options
> or support for other setups. It's public as a **reference**, or for people who want **exactly the same
> setup** as me.
>
> **Only run `install.sh` on a freshly installed, unconfigured Arch Linux system.** It installs a lot of
> packages (NVIDIA drivers included if you pick them), replaces your configs with symlinks, changes your login
> shell and can enable system services. Don't run it on a system you already use.

## Just want a piece of it?
You don't need the installer for that. Browse the repo and copy what you like, for example:
- `.config/quickshell/aurora/`: the shell (needs Quickshell; it reads its colours from `~/.cache/wal/colors.json`)
- `.config/hypr/`: Hyprland in the new Lua config format
- `.local/bin/`: small scripts (`setwall`, `brictl`, `sysact`, `tms`, ...)
- `.config/wal/templates/`: pywal16 templates for Hyprland, zathura, cava

## Installing (fresh Arch only)
```bash
git clone https://git.krolyxon.com/dotfiles ~/.dotfiles
cd ~/.dotfiles
./install.sh           # interactive: pick packages per group
./install.sh --yes     # pre-select the default packages, no pickers
./install.sh --check   # only compare installed packages with the lists, changes nothing
```
The repo has to live at `~/.dotfiles` (stow links into the parent directory).

What `install.sh` does:
1. Refuses to run as root or on anything other than Arch, and asks for confirmation if the system doesn't
   look fresh (another desktop's config, or lots of configs this repo doesn't provide).
2. Installs `stow gum git zsh`, shows the disclaimer, then lets you pick packages per group.
3. Runs `stow . --no-folding`. Files that are in the way are **moved** to `~/.dotfiles-backup/<date>/`, not deleted.
4. Sets zsh as your login shell.
5. Installs `paru` if it's missing, then installs the desktop packages and everything you picked.
6. Optionally copies `system/etc/keyd/default.conf` to `/etc/keyd` and enables `keyd` (capslock: tap esc, hold ctrl).

Afterwards, reboot and log in to Hyprland.

## Packages
The lists live in `packages/*.txt`: one package per line, `#` for comments, and a trailing `!` means
"listed, but not pre-selected".

| file | |
|---|---|
| `desktop.txt` | always installed: Hyprland, Quickshell, PipeWire, the tools the shell and keybinds call |
| `utils.txt` | CLI tools, fonts, media, small utilities |
| `dev.txt` | development tools |
| `gpu.txt` | Intel + NVIDIA (`nvidia-open-dkms`) drivers. Change this for your hardware |
| `optional.txt` | desktop apps |
| `aur.txt` | AUR packages (installed with paru) |
| `base.txt` | reference only, never installed: what the base install already provides |

## What's inside
| | |
|---|---|
| WM | Hyprland (Lua config), hypridle, hyprlock, hyprpaper |
| Shell / bar | aurora (Quickshell) |
| Theming | pywal16: picking a wallpaper in aurora (or `setwall`) re-themes everything |
| Terminal / shell | foot, zsh |
| Editor | Neovim (LazyVim) |
| Launcher / menus | aurora's runner (`aurora-run`, also a dmenu replacement for scripts) |
| Files | lf, pcmanfm |
| Music / video | mpd + ncmpcpp, mpv |
| Font / icons | JetBrainsMono Nerd Font, Yaru |
