-- source/input.lua

--------------------------------------------------
-- Global Input
--------------------------------------------------

hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",

        follow_mouse = 1,

        -- -1.0 .. 1.0
        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
        },

        repeat_delay = 300,
        repeat_rate = 50,
    },
})

--------------------------------------------------
-- Per-device Configuration
--------------------------------------------------

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})
