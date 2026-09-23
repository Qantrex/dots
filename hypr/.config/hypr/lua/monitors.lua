-- Monitors
-- https://wiki.hypr.land/configuring/core/monitors/

-- Internal laptop panel (Samsung, 2880x1800). scale 2 gives a 1440x900 logical
-- workspace, which keeps text sharp without fractional-scaling artifacts.
hl.monitor({
    output   = "eDP-1",
    mode     = "2880x1800@90",
    position = "0x0",
    scale    = 2,
})

-- External HDMI output mirrors the laptop panel.
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@60",
    position = "auto",
    scale    = 1,
    mirror   = "eDP-1",
})

-- Catch-all for anything else plugged in. Must stay last.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
