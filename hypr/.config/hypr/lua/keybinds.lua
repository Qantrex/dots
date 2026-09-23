-- Keybindings
-- https://wiki.hypr.land/configuring/core/binds/
-- Dispatchers: https://wiki.hypr.land/configuring/core/dispatchers/

local apps = require("lua.apps")

local mod = "SUPER"

--------------------------------------------------------------------------
-- Launchers
--------------------------------------------------------------------------

hl.bind(mod .. " + T", hl.dsp.exec_cmd(apps.terminal),    { description = "Terminal" })
hl.bind(mod .. " + E", hl.dsp.exec_cmd(apps.fileManager), { description = "File manager" })
hl.bind(mod .. " + A", hl.dsp.exec_cmd(apps.menu),        { description = "App launcher" })
hl.bind(mod .. " + R", hl.dsp.exec_cmd(apps.menu),        { description = "App launcher" })
hl.bind(mod .. " + C", hl.dsp.exec_cmd(apps.clipboard),   { description = "Clipboard history" })
hl.bind(mod .. " + L", hl.dsp.exec_cmd(apps.lock),        { description = "Lock screen" })

hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd(apps.emoji),     { description = "Emoji picker" })
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd(apps.ollama),    { description = "Ollama launcher" })
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(apps.wallpaper), { description = "Wallpaper picker" })

-- Reload Hyprland and restart the bar.
--
-- The old bind ran `hyprctl reload && pkill waybar waybar &`. pkill rejects a
-- second pattern ("only one pattern can be provided"), so it exited non-zero
-- and waybar was never killed or restarted -- the bind did nothing but reload.
hl.bind(
    mod .. " + SHIFT + R",
    hl.dsp.exec_cmd("hyprctl reload; pkill -x " .. apps.bar .. "; sleep 0.3; " .. apps.bar),
    { description = "Reload config and restart bar" }
)

--------------------------------------------------------------------------
-- Screenshots
--------------------------------------------------------------------------

-- grimblast is not installed on this machine, so the old bind was dead. grim,
-- slurp and wl-copy are installed, so this does the same job: select a region,
-- save it, and put it on the clipboard.
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd([[
    mkdir -p ~/Pictures/Screenshots &&
    f=~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png &&
    grim -g "$(slurp)" "$f" &&
    wl-copy < "$f" &&
    notify-send -i "$f" "Screenshot saved" "$f"
]]), { description = "Screenshot region to file and clipboard" })

-- Whole screen, clipboard only.
hl.bind(mod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd(
    'grim - | wl-copy && notify-send "Screenshot" "Full screen copied to clipboard"'
), { description = "Screenshot screen to clipboard" })

--------------------------------------------------------------------------
-- Window management
--------------------------------------------------------------------------

hl.bind(mod .. " + Q", hl.dsp.window.close(),                       { description = "Close window" })
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }),  { description = "Toggle floating" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }), { description = "Toggle pseudotile" })
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"),                { description = "Toggle split (dwindle)" })

hl.bind(
    mod .. " + F",
    hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }),
    { description = "Toggle fullscreen" }
)
hl.bind(
    mod .. " + SHIFT + F",
    hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }),
    { description = "Toggle maximized" }
)

-- Move focus.
local directions = { left = "left", right = "right", up = "up", down = "down" }
for key, dir in pairs(directions) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }),
        { description = "Focus " .. dir })
    -- Move the focused window the same way.
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }),
        { description = "Move window " .. dir })
end

--------------------------------------------------------------------------
-- Workspaces
--------------------------------------------------------------------------

for i = 1, 10 do
    local key = i % 10 -- workspace 10 lives on the 0 key
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }),
        { description = "Workspace " .. i })
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }),
        { description = "Move window to workspace " .. i })
end

-- Scratchpad.
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"),
    { description = "Toggle scratchpad" })
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }),
    { description = "Move window to scratchpad" })

-- Cycle workspaces with the scroll wheel.
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Drag to move, right-drag to resize.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--------------------------------------------------------------------------
-- Power profiles
--------------------------------------------------------------------------
--
-- Goes through powerprofile.sh rather than calling asusctl directly, so the
-- waybar module refreshes and a notification is shown. No root needed:
-- asusctl is authorised through polkit.
--
--   F1  Quiet        lazy fan curve, EPP=power        (heat over noise)
--   F2  Performance  aggressive fans, EPP=performance (full ~4.68 GHz boost)
--   F3  Balanced     the middle setting

for key, profile in pairs({ F1 = "quiet", F2 = "performance", F3 = "balanced" }) do
    hl.bind(mod .. " + " .. key, hl.dsp.exec_cmd(apps.powerprofile .. " " .. profile),
        { description = "Power profile: " .. profile })
end

--------------------------------------------------------------------------
-- Media and laptop function keys
--------------------------------------------------------------------------

-- swayosd-client both applies the change and draws the on-screen indicator.
--
-- The old config bound each of these keys twice -- once to wpctl/brightnessctl
-- and again to swayosd-client. Hyprland runs every matching bind in order, so
-- each press moved the volume twice (~10% per tap instead of 5%).
local osd = { locked = true, repeating = true }

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise"),      osd)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower"),      osd)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), osd)
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),  osd)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"),          osd)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"),          osd)

-- Player controls (playerctl).
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
