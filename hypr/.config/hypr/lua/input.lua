-- Input
-- https://wiki.hypr.land/configuring/core/config-options/

hl.config({
    input = {
        kb_layout = "de",

        follow_mouse = 1,

        -- -1.0 to 1.0; 0 means libinput's default acceleration.
        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
            -- Off while the pad registers phantom ~13 ms touches (Oct 2026);
            -- each one became a click. Re-enable after the hardware is fixed.
            tap_to_click   = false,
        },
    },
})

-- Three-finger horizontal swipe switches workspaces.
-- https://wiki.hypr.land/configuring/core/binds/gestures/
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- Per-device overrides.
-- https://wiki.hypr.land/configuring/core/devices/
--
-- The old config carried the upstream `epic-mouse-v1` placeholder, which
-- matches nothing. The real device names on this machine (from
-- `hyprctl devices`) are:
--   asue1a00:00-04f3:31de-touchpad
--   logitech-wireless-mouse-mx-master-3
--   at-translated-set-2-keyboard
--
-- hl.device({ name = "logitech-wireless-mouse-mx-master-3", sensitivity = -0.2 })
