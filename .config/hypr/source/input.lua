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
-- Gestures
--------------------------------------------------

hl.config({
    gestures = {
        -- swiping past the last workspace would create the next monitor's (11, 21, ...)
        workspace_swipe_create_new = false,
    },
})

-- 3-finger horizontal swipe: previous/next workspace on the focused monitor
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- 4-finger horizontal swipe: drag the focused window to the previous/next workspace
hl.gesture({
    fingers = 4,
    direction = "horizontal",
    action = "move",
})

-- 3-finger up: aurora's workspace overview
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.dispatch(hl.dsp.exec_cmd("qs -c aurora ipc call shell overview"))
    end,
})

-- 3-finger down: scratchpad (same special workspace as SUPER+S)
hl.gesture({
    fingers = 3,
    direction = "down",
    action = "special",
    workspace_name = "magic",
})

-- 3-finger pinch: zoom around the cursor
hl.gesture({
    fingers = 3,
    direction = "pinch",
    action = "cursorZoom",
    zoom_level = 2,
    mode = "live",
})

--------------------------------------------------
-- Per-device Configuration
--------------------------------------------------

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})
