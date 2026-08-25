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
            colors = { wal.colors.color14, wal.colors.color12 },
            angle = 45,
        },

        ["col.inactive_border"] = {
            colors = { wal.colors.color0, wal.colors.color0 },
            angle = 45,
        },
    },

    --------------------------------------------------
    -- Decoration
    --------------------------------------------------
    decoration = {
        -- rounding = 8,

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
    },
})
