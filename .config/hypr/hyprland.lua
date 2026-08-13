
terminal = "foot"
menu = "fuzzel"
browser = "librewolf"
mainMod = "SUPER"

-- -----------------------------------------------------
-- Path to home
-- -----------------------------------------------------
HOME = os.getenv("HOME")


-- Theme (pywal)
require(os.getenv("HOME") .. "/.cache/wal/colors.lua")


-- -----------------------------------------------------
-- Autostart
-- -----------------------------------------------------

hl.on("hyprland.start", function()
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

-- hl.config({
--     plugin = {
--         hyprsplit = {
--             num_workspaces = 10,
--             persistent_workspaces = true,
--         },
--
--         ["split-monitor-workspaces"] = {
--             count = 10,
--             keep_focused = true,
--             enable_notifications = false,
--             enable_persistent_workspaces = true,
--         },
--     },
-- })

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
