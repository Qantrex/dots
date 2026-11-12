-- Programs used throughout the config.
-- Required by keybinds.lua and autostart.lua so a change here applies everywhere.
--
-- Commands are run through `sh -c`, so `~` and shell syntax are fine.

-- The shell (bar, popouts, notifications, OSD, launcher) is Quickshell:
-- ~/.config/quickshell (dotfiles: quickshell/). The launcher's modes are opened
-- over its IPC; `qs ipc show` lists every entry point.
local function launcher(mode) return "qs ipc call launcher toggle " .. mode end

-- The big autostarted apps run in their own systemd scope
-- (app.slice/app-<name>-<pid>.scope). Otherwise they share the session scope
-- with Hyprland, which only root may push to swap, and `away` can't free their
-- RAM for the AI node (2026-11-06: Firefox and most of Vesktop sat in
-- session-N.scope). systemd-run --scope keeps the PID, so the workspace
-- placement in autostart.lua still works. The terminal stays outside on
-- purpose: what runs in it should never be pushed to swap.
local function scoped(name, cmd)
    return "systemd-run --user --scope --slice=app.slice --collect --quiet --unit=app-"
        .. name .. "-$$ " .. cmd
end

return {
    terminal    = "foot",
    fileManager = "dolphin",
    browser     = scoped("firefox", "firefox"),
    -- spotify-adblock ships a shared library, not an executable, so it has to
    -- be LD_PRELOADed into spotify. The old config ran "spotify-adblock"
    -- directly, which is not a command -- Spotify never actually autostarted.
    music       = scoped("spotify", "env LD_PRELOAD=/usr/lib/spotify-adblock.so spotify"),
    -- aerc runs in its own foot window with a fixed app-id, so a window rule
    -- can send it to its workspace without catching every other terminal.
    mail        = scoped("aerc", "foot --app-id=aerc aerc"),
    mailHelp    = "~/.config/scripts/aerc-cheatsheet.sh",
    chat        = scoped("vesktop", "vesktop --enable-features=WaylandWindowDecorations --ozone-platform-hint=auto"),

    menu        = launcher("apps"),
    emoji       = launcher("emoji"),
    clipboard   = launcher("clipboard"),
    wallpaper   = launcher("wallpaper"),
    screenshot  = launcher("screenshot"),
    session     = launcher("power"),
    notifications = "qs ipc call bar popout notifs",
    powerprofile = "~/.config/scripts/powerprofile.sh",
    touchpad    = "~/.config/scripts/touchpad.sh",
    vault       = "~/.config/scripts/vault.sh",
    idle        = "~/.config/scripts/idle.sh",
    typing      = "~/.config/scripts/homerow.sh",
    claudeScreen = "~/.config/scripts/claude-screen/capture.py",

    lock        = "hyprlock",
    -- qs under a supervisor that restarts it after a crash; `shell.sh restart`
    -- restarts it on purpose. (The process is `qs`, the symlink, not `quickshell`.)
    shell       = "~/.config/scripts/shell.sh",

    -- Absolute path: hyprpaper does not expand `~`.
    wallpaperImage = "/home/kbauer/Pictures/Wallpapers/synthwave-mountain-sun.jpg",
}
