hl.config({
    --------------------------------------------------
    -- General
    --------------------------------------------------
    general = {
        gaps_in = 2,
        gaps_out = 2,
        border_size = 2,

        resize_on_border = false,
        allow_tearing = false,

        layout = "master",

        ["col.active_border"] = {
            colors = { colors.primary, colors.primary },
            angle = 45,
        },

        ["col.inactive_border"] = {
            colors = { colors.surface_highest, colors.surface_highest },
            angle = 45,
        },
    },

    -- groups: the same colours, the bar in Space Mono like aurora's labels
    group = {
        ["col.border_active"] = colors.primary,
        ["col.border_inactive"] = colors.surface_highest,
        ["col.border_locked_active"] = colors.primary,
        ["col.border_locked_inactive"] = colors.outline_variant,
        groupbar = {
            font_family = "Space Mono",
            text_color = colors.on_surface,
            ["col.active"] = colors.surface_highest,
            ["col.inactive"] = colors.surface,
            ["col.locked_active"] = colors.surface_highest,
            ["col.locked_inactive"] = colors.surface,
        },
    },

    --------------------------------------------------
    -- Decoration
    --------------------------------------------------
    decoration = {
        rounding = 14,   -- round corners like aurora's cards (Nothing look)

        blur = {
            enabled = true,
            size = 3,
            passes = 3,
            new_optimizations = true,
            vibrancy = 0.1696,
            ignore_opacity = true,
        },
    },

    --------------------------------------------------
    -- Animations
    --------------------------------------------------
    animations = {
        enabled = false,

        bezier = {
            {
                name = "myBezier",
                points = { 0.05, 0.9, 0.1, 1.05 },
            },
        },

        animation = {
            { "windows", 1, 2, "myBezier" },
            { "windowsOut", 1, 2, "default", "popin 80%" },
            { "border", 1, 10, "default" },
            { "borderangle", 1, 8, "default" },
            { "fade", 1, 7, "default" },
            { "workspaces", 1, 1, "default" },
        },
    },

    --------------------------------------------------
    -- Dwindle
    --------------------------------------------------
    dwindle = {
        preserve_split = true,
    },

    --------------------------------------------------
    -- Master
    --------------------------------------------------
    master = {
        new_status = "master",
        new_on_top = true,
    },

    --------------------------------------------------
    -- Misc
    --------------------------------------------------
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,

        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,

        vrr = 0,

        -- dwm monocle: focusing another window (super+tab) makes it fullscreen instead of exiting fullscreen
        on_focus_under_fullscreen = 1,
    },
})
