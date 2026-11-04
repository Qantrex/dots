-- Programs used throughout the config.
-- Required by keybinds.lua and autostart.lua so a change here applies everywhere.
--
-- Commands are run through `sh -c`, so `~` and shell syntax are fine.

local host = require("lua.host")

-- waybar reads config-<hostname>.jsonc when the machine has one (it includes the shared config.jsonc).
local barConfig = host.file("waybar", "config", "jsonc")

return {
    terminal    = "foot",
    fileManager = "dolphin",
    browser     = "firefox",
    -- spotify-adblock ships a shared library, not an executable, so it has to
    -- be LD_PRELOADed into spotify. The old config ran "spotify-adblock"
    -- directly, which is not a command -- Spotify never actually autostarted.
    music       = "env LD_PRELOAD=/usr/lib/spotify-adblock.so spotify",
    -- aerc runs in its own foot window with a fixed app-id, so a window rule
    -- can send it to its workspace without catching every other terminal.
    mail        = "foot --app-id=aerc aerc",
    mailHelp    = "~/.config/scripts/aerc-cheatsheet.sh",
    chat        = "vesktop --enable-features=WaylandWindowDecorations --ozone-platform-hint=auto",

    menu        = 'wofi --show drun --prompt="App Launcher"',
    emoji       = "wofimoji",
    clipboard   = "~/.config/scripts/wofi-cliphist.sh",
    wallpaper   = "~/.config/scripts/wofi-wallpaper.sh",
    screenshot  = "~/.config/scripts/wofi-screenshot.sh",
    powerprofile = "~/.config/scripts/powerprofile.sh",
    touchpad    = "~/.config/scripts/touchpad.sh",
    vault       = "~/.config/scripts/vault.sh",
    idle        = "~/.config/scripts/idle.sh",
    typing      = "~/.config/scripts/homerow.sh",
    claudeScreen = "~/.config/scripts/claude-screen/capture.py",

    lock        = "hyprlock",
    bar         = "waybar",   -- process name, for pkill -x
    barStart    = barConfig and ("waybar -c " .. barConfig) or "waybar",

    -- Absolute path: hyprpaper does not expand `~`.
    wallpaperImage = "/home/kbauer/Pictures/Wallpapers/synthwave-mountain-sun.jpg",
}
