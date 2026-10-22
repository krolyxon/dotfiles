-- -----------------------------------------------------
-- Monitors (replaced kanshi: its wlr-output-management state overrode every hl.monitor() rule)
-- -----------------------------------------------------
-- Defaults are below. aurora's settings app (Display) saves per-output changes and the layout to
-- ~/.config/aurora/monitors.lua (generated, not in the repo) and changes them live through
-- `hyprctl eval 'monitors.apply()'`.
-- layout: "extend"   every connected output on
--         "laptop"   only the laptop panel
--         "external" laptop panel off while another output is on (it comes back when that one is unplugged)
monitors = {
    laptop = "eDP-1",
    layout = "extend",
    outputs = {
        ["eDP-1"]    = { mode = "highrr",    position = "0x0",    scale = 1 },
        ["HDMI-A-1"] = { mode = "1920x1080", position = "1920x0", scale = 1 },
    },
    fallback = { mode = "preferred", position = "auto", scale = 1 },   -- any other output
}

local ok, saved = pcall(dofile, HOME .. "/.config/aurora/monitors.lua")
if ok and type(saved) == "table" then
    if saved.layout == "extend" or saved.layout == "laptop" or saved.layout == "external" then
        monitors.layout = saved.layout
    end
    for name, s in pairs(saved.outputs or {}) do monitors.outputs[name] = s end
end

local function rule(name, s, off)
    -- disabled = false explicitly: hl.monitor() merges into the output's existing rule
    if off then return { output = name, disabled = true } end
    return { output = name, mode = s.mode, position = s.position, scale = s.scale, disabled = false }
end

-- is an output other than the laptop panel (and `gone`, which is being unplugged) on?
local function externalOn(gone)
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= monitors.laptop and m.name ~= gone then return true end
    end
    return false
end

function monitors.apply(gone)
    local l = monitors.layout
    hl.monitor(rule("", monitors.fallback, l == "laptop"))
    for name, s in pairs(monitors.outputs) do
        if name ~= monitors.laptop then hl.monitor(rule(name, s, l == "laptop")) end
    end
    hl.monitor(rule(monitors.laptop, monitors.outputs[monitors.laptop] or monitors.fallback,
        l == "external" and externalOn(gone)))
end

monitors.apply()
hl.on("monitor.added", function() monitors.apply() end)
hl.on("monitor.removed", function(m) monitors.apply(m.name) end)
