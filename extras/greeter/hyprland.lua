-- Compositor for the boot login screen (greetd runs it as the `greeter` user; installed to
-- /etc/greetd/hyprland.lua by `setup.sh greeter`). Only what the greeter needs: the
-- iGPU setup, the panel, keyboard / touchpad, cursor, no logo or splash. It runs the
-- Quickshell greeter and exits with it, so greetd can start the user's session.

local function exists(p) local f = io.open(p, "r"); if f then f:close() return true end return false end
-- Hybrid GPU (TUF F16): same as the desktop config
if exists("/dev/dri/igpu") then
    hl.env("AQ_DRM_DEVICES", exists("/dev/dri/dgpu") and "/dev/dri/igpu:/dev/dri/dgpu" or "/dev/dri/igpu")
end
hl.env("XCURSOR_THEME", "WhiteSur-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "WhiteSur-cursors")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")

hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.0 })
hl.monitor({ output = "",      mode = "preferred", position = "auto", scale = "auto" })

hl.config({
    misc = {
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color        = "rgb(0b0c0b)",
    },
    animations = { enabled = false },
    input = {
        kb_layout = "us",
        touchpad = {
            natural_scroll = true,
            tap_to_click   = true,
        },
    },
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p /etc/greetd/quickshell; hyprctl dispatch 'hl.dsp.exit()'")
end)
