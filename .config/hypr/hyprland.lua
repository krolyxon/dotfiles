terminal = "foot"
menu = "fuzzel"
browser = "librewolf"
mainMod = "SUPER"

-- -----------------------------------------------------
-- Path to home
-- -----------------------------------------------------
HOME = os.getenv("HOME")


-- Theme (pywal)
dofile(HOME .. "/.cache/wal/hyprland-colors.lua")

-- -----------------------------------------------------
-- Autostart
-- -----------------------------------------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hyprpm reload -n")
    hl.exec_cmd("kanshi")
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("gammastep")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/setwall -n")
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
require("source.environment_variables")
require("source.permissions")
require("source.appearance")
require("source.input")
require("source.keybinds")


--------------------------------------------------
-- Window rules
--------------------------------------------------
hl.window_rule({
    name = "suppress-maximize-events",

    match = {
        class = ".*",
    },

    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",

    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },

    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",

    match = {
        class = "hyprland-run",
    },

    move = "20 monitor_h-120",
    float = true,
})
