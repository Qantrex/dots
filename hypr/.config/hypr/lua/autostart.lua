-- Autostart
-- https://wiki.hypr.land/configuring/core/autostart/
--
-- `hyprland.start` fires once, when the compositor comes up -- not on
-- `hyprctl reload`. It is the Lua equivalent of the old `exec-once`.

local apps = require("lua.apps")
local host = require("lua.host")
local ws   = require("lua.workspaces")

hl.on("hyprland.start", function()
    -- Hand the session environment to systemd and D-Bus first, so services
    -- started below (and any portal launched on demand) inherit it.
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd " ..
        "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland HYPRLAND_INSTANCE_SIGNATURE"
    )

    -- Authentication agent, for anything asking for polkit privileges.
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Hardware lighting off (desktop only; one-shot, nothing keeps running).
    hl.exec_cmd("sh -c 'command -v openrgb >/dev/null && for d in 0 1 2 3 4 5; do openrgb -d $d -m direct -c 000000; done'")

    -- The shell: bar, notifications, OSD, launcher and the low-battery
    -- warnings, all in one Quickshell process.
    hl.exec_cmd(apps.shell)

    -- The quick-ask Claude window (SUPER+D) starts hidden, so it opens instantly.
    hl.exec_cmd(apps.ask .. " --preload")

    -- Wallpaper: start hyprpaper without a config file, wait for its socket, then
    -- set the last picked wallpaper over IPC. hyprpaper.conf only turns off the
    -- splash text (on by default since hyprpaper 0.8); the old preload/wallpaper
    -- lines there were ignored, so the picture is set here.
    hl.exec_cmd(string.format([[
        hyprpaper &
        for _ in $(seq 1 50); do
            hyprctl hyprpaper listactive >/dev/null 2>&1 && break
            sleep 0.2
        done
        w=$(cat "$HOME/.cache/wallpaper/last" 2>/dev/null)
        [ -f "$w" ] || w="%s"
        hyprctl hyprpaper wallpaper ",$w" >/dev/null 2>&1
    ]], apps.wallpaperImage))

    -- Clipboard history.
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Laptop: always start quiet; opt into Performance with SUPER+F2.
    -- The desktop has no asusctl; it goes quiet through `away` (pc-quiet).
    if not host.is_pc then hl.exec_cmd(apps.powerprofile .. " quiet") end

    -- Idle handling: dim, lock, screen off, and suspend on battery (the
    -- desktop: lock + quiet mode, never suspend).
    -- See idle.sh for the timings and why it is a script.
    hl.exec_cmd(apps.idle)

    -- Cursor theme for GTK applications. `cursor.sync_gsettings_theme` is on
    -- by default and usually covers this, but setting it explicitly costs
    -- nothing and survives other tools overwriting the value.
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")

    -- Dark everywhere. On Wayland, GTK apps take their theme from gsettings
    -- rather than settings.ini, and libadwaita apps, Firefox, Chrome and web
    -- pages' prefers-color-scheme follow color-scheme (via the portal).
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Monochrome'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Mono'")

    -- Applications, each on its own workspace, without stealing focus.
    hl.exec_cmd(apps.terminal, { workspace = "1 silent" })
    hl.exec_cmd(apps.browser,  { workspace = "2 silent" })
    hl.exec_cmd(apps.mail,     { workspace = ws.mail .. " silent" })
    hl.exec_cmd(apps.music,    { workspace = ws.music .. " silent" })
    -- The old config passed `%U` to vesktop. That is a .desktop field code and
    -- means nothing on a command line -- vesktop received it as a literal
    -- argument.
    hl.exec_cmd(apps.chat,     { workspace = ws.chat .. " silent" })
end)
