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

-- aurora's settings app: a normal window, opened maximized (glyph's full-screen prefs layout, but still a window)
hl.window_rule({
    name = "aurora-settings",

    match = {
        class = "^org.quickshell$",
        title = "^aurora settings$",
    },

    maximize = true,
})
