-- source/environment_variables.lua

--------------------------------------------------
-- Environment Variables
--------------------------------------------------
local envs = {
    HYPRSHOT_DIR = "/home/krolyxon/pix/ss/",
    XCURSOR_SIZE = "24",
    HYPRCURSOR_SIZE = "24",

    XDG_CURRENT_DESKTOP = "Hyprland",
    XDG_SESSION_TYPE = "wayland",
    XDG_SESSION_DESKTOP = "Hyprland",

    GDK_BACKEND = "wayland,x11,*",
    QT_QPA_PLATFORM = "wayland;xcb",
    SDL_VIDEODRIVER = "Wayland",
    CLUTTER_BACKEND = "wayland",
}

for k, v in pairs(envs) do
    hl.env(k, v)
end

--------------------------------------------------
-- NVIDIA (uncomment if needed)
--------------------------------------------------

-- hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- hl.env("__VK_LAYER_NV_optimus", "NVIDIA_only")
-- hl.env("GBM_BACKEND", "nvidia-drm")
-- hl.env("WLR_NO_HARDWARE_CURSORS", "1")
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
