-- Keybindings
-- https://wiki.hypr.land/configuring/core/binds/
-- Dispatchers: https://wiki.hypr.land/configuring/core/dispatchers/

local apps = require("lua.apps")
local host = require("lua.host")

local mod = "SUPER"

--------------------------------------------------------------------------
-- Launchers
--------------------------------------------------------------------------

hl.bind(mod .. " + T", hl.dsp.exec_cmd(apps.terminal),    { description = "Terminal" })
hl.bind(mod .. " + E", hl.dsp.exec_cmd(apps.files),       { description = "Files (yazi)" })
hl.bind(mod .. " + CTRL + E", hl.dsp.exec_cmd(apps.fileManager), { description = "Files (Nautilus)" })
hl.bind(mod .. " + A", hl.dsp.exec_cmd(apps.menu),        { description = "App launcher" })
hl.bind(mod .. " + R", hl.dsp.exec_cmd(apps.menu),        { description = "App launcher" })
hl.bind(mod .. " + C", hl.dsp.exec_cmd(apps.clipboard),   { description = "Clipboard history" })
hl.bind(mod .. " + L", hl.dsp.exec_cmd(apps.lock),        { description = "Lock screen" })
hl.bind(mod .. " + H", hl.dsp.exec_cmd(apps.mailHelp),    { description = "Toggle aerc cheatsheet" })
hl.bind(mod .. " + D", hl.dsp.exec_cmd(apps.ask),         { description = "Quick ask (Claude)" })
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd(apps.ask .. " --clip"), { description = "Quick ask about the clipboard" })
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd("~/.config/scripts/claude-peek.sh --toggle"),
    { description = "Answer a waiting Claude session here" })

hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(apps.typing),    { description = "Typing test (homerow)" })
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd(apps.emoji),     { description = "Emoji picker" })
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(apps.wallpaper), { description = "Wallpaper picker" })

-- rbw asks for the Bitwarden master password, then the vault opens in the
-- default file manager (Nautilus). Already unlocked: just opens it.
hl.bind(
    mod .. " + SHIFT + V",
    hl.dsp.exec_cmd(apps.vault .. " open && xdg-open ~/Vault"),
    { description = "Unlock vault and open it" }
)

-- Reload Hyprland and restart the shell. Quickshell reloads its own config
-- when a file changes; the restart is for when it got stuck.
hl.bind(
    mod .. " + SHIFT + R",
    hl.dsp.exec_cmd("hyprctl reload; " .. apps.shell .. " restart"),
    { description = "Reload config and restart the shell" }
)

-- Notifications and the session menu (lock, suspend, log out, restart, shut down).
hl.bind(mod .. " + N",      hl.dsp.exec_cmd(apps.notifications), { description = "Notifications" })
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd(apps.session),       { description = "Session menu" })

--------------------------------------------------------------------------
-- Screenshots
--------------------------------------------------------------------------

-- Menu: region / window / monitor / all screens (the launcher's screenshot mode).
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(apps.screenshot), { description = "Screenshot menu" })

-- Straight to a region: saved to ~/Pictures/Screenshots and on the clipboard.
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh region"),
    { description = "Screenshot region to file and clipboard" })

-- Region with flameshot, ask Claude Code about it, answer opens in a floating
-- foot and lands on the clipboard. Screenshots and answers: ~/.cache/claude-screen
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd(apps.claudeScreen),
    { description = "Ask Claude about a screenshot" })

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
    mod .. " + ALT + F",
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
-- ALT, not SHIFT: SUPER+SHIFT+S is the screenshot menu.
hl.bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }),
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
-- bar refreshes and a notification is shown. No root needed:
-- asusctl is authorised through polkit.
--
--   F1  Quiet        lazy fan curve, EPP=power        (heat over noise)
--   F2  Performance  aggressive fans, EPP=performance (full ~4.68 GHz boost)
--   F3  Balanced     the middle setting

-- Desktop: no asusctl. SUPER+F1 runs `away` instead (lock, screens off,
-- quiet mode; the AI node keeps running).
if host.is_pc then
    hl.bind(mod .. " + F1", hl.dsp.exec_cmd("~/.local/bin/away"),
        { description = "Away: lock, screens off, quiet (AI node stays up)" })
else
    for key, profile in pairs({ F1 = "quiet", F2 = "performance", F3 = "balanced" }) do
        hl.bind(mod .. " + " .. key, hl.dsp.exec_cmd(apps.powerprofile .. " " .. profile),
            { description = "Power profile: " .. profile })
    end
end

--------------------------------------------------------------------------
-- Media and laptop function keys
--------------------------------------------------------------------------

-- wpctl / brightnessctl do the change; the shell's OSD shows it. Volume
-- changes reach the OSD through PipeWire by themselves; brightness has no
-- change event, so those binds tell the shell. Bind each key once only:
-- Hyprland runs every matching bind, so a second one doubles the step.
local osd = { locked = true, repeating = true }
local brightness = "brightnessctl -q -e4 -n2 set 5%%%s && qs ipc call osd brightness"

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), osd)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        osd)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       osd)
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     osd)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(string.format(brightness, "+")),                    osd)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(string.format(brightness, "-")),                    osd)

-- Fn+F6. The firmware only sends the key; touchpad.sh does the switching and
-- updates the bar.
hl.bind("XF86TouchpadToggle", hl.dsp.exec_cmd(apps.touchpad .. " toggle"),
    { description = "Toggle touchpad" })

-- Player controls (playerctl).
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
