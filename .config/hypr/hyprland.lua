terminal = "foot"
menu = "aurora-run"   -- aurora's runner
browser = "librewolf"
mainMod = "SUPER"

-- -----------------------------------------------------
-- Path to home
-- -----------------------------------------------------
HOME = os.getenv("HOME")


-- Theme (pywal16)
wal = dofile(HOME .. "/.cache/wal/hyprland-colors.lua")

-- -----------------------------------------------------
-- Autostart
-- -----------------------------------------------------
hl.on("hyprland.start", function()
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
    hl.exec_cmd("hyprpaper")   -- wallpaper is set by aurora (Wall.qml), it reads hyprpaper.conf
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
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
