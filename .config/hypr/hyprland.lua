terminal = "foot"
menu = "aurora-run"   -- aurora's runner
browser = "librewolf"
mainMod = "SUPER"

-- -----------------------------------------------------
-- Path to home
-- -----------------------------------------------------
HOME = os.getenv("HOME")


-- Theme (matugen, run by aurora on every wallpaper change; fallback until it has run once)
local ok, c = pcall(dofile, HOME .. "/.cache/matugen/hyprland-colors.lua")
colors = ok and c or { primary = "rgba(80d5cbff)", outline_variant = "rgba(3f4947ff)" }

-- -----------------------------------------------------
-- Autostart
-- -----------------------------------------------------
hl.on("hyprland.start", function()
    -- GTK3 on Wayland reads its theme + icons from gsettings, not settings.ini (colours: gtk-3.0/gtk.css, matugen)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hyprpm reload -n")
    -- aurora is a systemd unit: hand it the login env (.zprofile: SUDO_ASKPASS, EDITOR, XDG dirs, ...)
    hl.exec_cmd("dbus-update-activation-environment --systemd --all && systemctl --user start aurora")
    -- hl.exec_cmd("waybar")
    -- hl.exec_cmd("swaync")
    hl.exec_cmd("gammastep")
    hl.exec_cmd("hypridle")
    -- hl.exec_cmd("blueman-applet")
    -- no hyprpaper: aurora draws the wallpaper itself (Back.qml / WallView.qml)
    -- polkit agent: aurora (Agents.qml); it starts hyprpolkitagent itself if it can't register
end)

--------------------------------------------------
-- Plugins
--------------------------------------------------
package.path = package.path .. ";./?.lua;./?/init.lua"
smw = require("plugins.split-monitor-workspaces")
smw.setup({
    workspace_count = 10,
})

-- -----------------------------------------------------
-- SOURCE FILES
-- -----------------------------------------------------
require("source.monitors")
require("source.environment_variables")
require("source.permissions")
require("source.appearance")
require("source.input")
require("source.keybinds")
require("source.window_rules")

-- aurora's settings app: overrides on top of everything above (~/.config/aurora/hypr.lua, generated, not in the repo).
-- Missing or broken file = the defaults from the files above.
local ok, overrides = pcall(dofile, HOME .. "/.config/aurora/hypr.lua")
if ok and type(overrides) == "table" then hl.config(overrides) end
