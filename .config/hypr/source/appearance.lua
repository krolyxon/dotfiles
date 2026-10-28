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

    animations = {
        enabled = true,
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

--------------------------------------------------
-- Animations (glyph-rice's set, retimed to aurora's motion: speed is in 100ms, aurora's panels take 350ms)
--------------------------------------------------
-- aurora's glide (Theme.glide): ease-out-quart without overshoot
hl.curve("glide", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })

-- aurora's own layers animate themselves (no_anim in window_rules.lua); these only hit other layers (slurp, ...)
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "glide", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 2.5, bezier = "glide" })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "glide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "emphasizedAccel" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "glide" })
-- glyph slides vertically (slidevert) for its vertical swipe; ours swipes horizontally (input.lua)
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "glide", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "glide", style = "slidefadevert 15%" })

hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "glide" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 2.5, bezier = "glide" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "glide" })
