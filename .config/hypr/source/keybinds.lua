---------------------
---- KEYBINDINGS ----
---------------------
-- See https://wiki.hypr.land/Configuring/Basics/Binds/ for more

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

-- bind = $mainMod SHIFT, R, togglefloating,
-- Smart Float: Toggle float -> Resize to 90% -> Center
hl.bind(
    mainMod .. "+ SHIFT + R",
    hl.dsp.exec_cmd([[
        if hyprctl activewindow | grep -q 'floating: 0'; then
            W=$(hyprctl monitors -j | jq '.[] | select(.focused) | ((.width / .scale) * 0.9) | floor')
            H=$(hyprctl monitors -j | jq '.[] | select(.focused) | ((.height / .scale) * 0.9) | floor')
            hyprctl --batch "dispatch hl.dsp.window.float({action='set'}); dispatch hl.dsp.window.resize({x=${W}, y=${H}, relative=false})"
            hyprctl dispatch "hl.dsp.window.center()"
        else
            hyprctl dispatch "hl.dsp.window.float({action='unset'})"
        fi
    ]]),
    { description = "Smart Float" }
)


hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
-- bind = $mainMod SHIFT, P, pseudo, # dwindle
-- (left commented out to mirror the original file)
hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next({ next = false }), { repeating = true })
hl.bind(mainMod .. " + b", hl.dsp.exec_cmd("killall waybar || waybar"))
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd("fuzzelunicode"))
hl.bind(mainMod .. " + escape", hl.dsp.exec_cmd("sysact"))

-- Applications
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser))
hl.bind("PRINT", hl.dsp.exec_cmd("hypr_screenshot.sh"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hypr_screenshot.sh"))

-- Music Controls
hl.bind(mainMod .. " + m", hl.dsp.exec_cmd(terminal .. " -e zsh -i -c \"ncmpcpp\""))
hl.bind(mainMod .. " + p", hl.dsp.exec_cmd("mpc toggle"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("mpc seek +10"), { repeating = true })
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("mpc seek -10"), { repeating = true })
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.exec_cmd("mpc next"))
hl.bind(mainMod .. " + SHIFT + comma", hl.dsp.exec_cmd("mpc prev"))

-- Swap current focused window with master
hl.bind(mainMod .. " + space", hl.dsp.layout("swapwithmaster"))

-- Resize windows with h/j/k/l
hl.bind(mainMod .. " + h", hl.dsp.window.resize({ x = -30, y = 0, relative = true}), { repeating = true })
hl.bind(mainMod .. " + l", hl.dsp.window.resize({ x = 30, y = 0, relative = true}), { repeating = true })
hl.bind(mainMod .. " + k", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
hl.bind(mainMod .. " + j", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })


-- -----------------------------------------------------
-- Workspace switching
-- -----------------------------------------------------

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0

    -- Switch to workspace
    hl.bind(
        mainMod .. " + " .. key,
        hl.dsp.focus({ workspace = i })
    )

    -- Move active window to workspace
    hl.bind(
        mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i, follow = false })
    )
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scratchpad like DWM
hl.workspace_rule({ workspace = "special:h", on_created_empty = terminal })
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.workspace.toggle_special("h"))

-- --- Accessibility: Zoom ---
hl.config({ cursor = { zoom_disable_aa = true } })

hl.bind(
    "SUPER + equal",
    function()
        local z = hl.get_config("cursor.zoom_factor")
        hl.config({ cursor = { zoom_factor = z * 1.25 } })
    end,
    { description = "Zoom In", repeating = true }
)

hl.bind(
    "SUPER + minus",
    function()
        local z = hl.get_config("cursor.zoom_factor")
        local nz = z / 1.25
        if nz < 1.0 then nz = 1.0 end
        hl.config({ cursor = { zoom_factor = nz } })
    end,
    { description = "Zoom Out", repeating = true }
)

hl.bind(
    "SUPER + BACKSPACE",
    function()
        hl.config({ cursor = { zoom_factor = 1.0 } })
    end,
    { description = "Reset Zoom", locked = true }
)

-- Screen Rotate
hl.bind(mainMod .. " + CTRL + comma", hl.dsp.exec_cmd("hypr_screen_rotate.py +90"),
    { locked = true, desc = "Rotate Screen Anti-Clockwise" })
hl.bind(mainMod .. " + CTRL + period", hl.dsp.exec_cmd("hypr_screen_rotate.py -90"),
    { locked = true, desc = "Rotate Screen Clockwise" })

-- --- Hyprshade (Visual Filters) ---
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("hypr_shader_menu.sh"), { desc = "Shader Menu" })
hl.bind(mainMod .. " + CTRL + X", hl.dsp.exec_cmd("hyprshade off"), { locked = true, desc = "Disable Shader" })
hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("hyprshade on vibrance"), { locked = true, desc = "Vibrant Shader" })

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.local/bin/brictl -"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.local/bin/brictl +"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
