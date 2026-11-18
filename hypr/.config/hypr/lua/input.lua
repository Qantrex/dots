-- Input
-- https://wiki.hypr.land/configuring/core/config-options/

local host = require("lua.host")

hl.config({
    input = {
        kb_layout = "de",

        -- Laptop: the keyboard decides focus. The mouse only moves it with a
        -- click (2 = "detached"); hovering still scrolls the window under it.
        -- Before, a nudge of the mouse handed keyboard focus to whatever window
        -- the resting cursor was over, e.g. right after SUPER+D or SUPER+V.
        -- The PC keeps focus-follows-mouse: SUPER+N picks the screen under the
        -- cursor (lua/workspaces.lua).
        follow_mouse = host.is_pc and 1 or 2,
        -- Laptop: no focus jump to the window under the cursor when a window
        -- switches between tiled and floating (SUPER+V).
        float_switch_override_focus = host.is_pc and 1 or 0,

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

-- Touchpad on/off (Fn+F6 and the bar) is switched live by
-- scripts/touchpad.sh. Reading its state file here keeps a reload or restart
-- from turning the touchpad back on. Keep the path and names in sync with it.
local touchpadOff = io.open(os.getenv("HOME") .. "/.local/state/touchpad-off")
if touchpadOff then touchpadOff:close() end
for _, name in ipairs({ "asue1a00:00-04f3:31de-touchpad", "asue1a00:00-04f3:31de-mouse" }) do
    hl.device({ name = name, enabled = touchpadOff == nil })
end
