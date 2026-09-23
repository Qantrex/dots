-- Programs used throughout the config.
-- Required by keybinds.lua and autostart.lua so a change here applies everywhere.
--
-- Commands are run through `sh -c`, so `~` and shell syntax are fine.

return {
    terminal    = "foot",
    fileManager = "dolphin",
    browser     = "firefox",
    -- spotify-adblock ships a shared library, not an executable, so it has to
    -- be LD_PRELOADed into spotify. The old config ran "spotify-adblock"
    -- directly, which is not a command -- Spotify never actually autostarted.
    music       = "env LD_PRELOAD=/usr/lib/spotify-adblock.so spotify",
    chat        = "vesktop --enable-features=WaylandWindowDecorations --ozone-platform-hint=auto",

    menu        = 'wofi --show drun --prompt="App Launcher"',
    emoji       = "wofimoji",
    clipboard   = "~/.config/scripts/wofi-cliphist.sh",
    wallpaper   = "~/.config/scripts/wofi-wallpaper.sh",
    ollama      = "~/.config/scripts/ollama-launcher.sh",
    powerprofile = "~/.config/scripts/powerprofile.sh",

    lock        = "hyprlock",
    bar         = "waybar",

    -- Absolute path: hyprpaper does not expand `~`.
    wallpaperImage = "/home/kbauer/Pictures/Wallpapers/wallpaperflare.com_wallpaper.jpg",
}
