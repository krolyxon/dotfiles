hl.config({
    ecosystem = {
        enforce_permissions = true,
    },
})

hl.permission({
    binary = "/usr/(bin|local/bin)/grim",
    type = "screencopy",
    mode = "allow",
})

hl.permission({
    binary = "/usr/(bin|local/bin)/hyprlock",
    type = "screencopy",
    mode = "allow",
})

hl.permission({
    binary = "/usr/(bin|local/bin)/hyprpicker",
    type = "screencopy",
    mode = "allow",
})

hl.permission({
    binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland",
    type = "screencopy",
    mode = "allow",
})

hl.permission({
    binary = "/usr/(bin|local/bin)/hyprpm",
    type = "plugin",
    mode = "allow",
})

hl.permission({
    binary = "${lib.escapeRegex (lib.getExe config.programs.hyprlock.package)}",
    type = "screencopy",
    mode = "allow",
})
