-- Monitors
-- https://wiki.hypr.land/configuring/core/monitors/

-- Each machine gets its own layout: the same port name means different things
-- on the laptop (HDMI mirrors the panel) and the desktop (HDMI is the main screen).
local function hostname()
    local file = io.open("/etc/hostname")
    if not file then return "" end
    local name = file:read("*l") or ""
    file:close()
    return name
end

if hostname() == "bauarch-pc" then
    -- Main screen, matched by model so it stays right whichever port it's on.
    hl.monitor({
        output   = "desc:AOC Q27G2G4",
        mode     = "2560x1440@144",
        position = "0x0",
        scale    = 1,
    })

    -- Side screen, in reversed portrait (transform 3 = 270 degrees).
    hl.monitor({
        output    = "desc:AOC 27G2G8",
        mode      = "1920x1080@240",
        position  = "2560x0",
        scale     = 1,
        transform = 3,
        vrr       = 2, -- adaptive sync in fullscreen only
    })
else
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
end

-- Catch-all for anything else plugged in. Must stay last.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
