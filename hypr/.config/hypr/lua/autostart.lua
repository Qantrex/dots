-- Autostart
-- https://wiki.hypr.land/configuring/core/autostart/
--
-- `hyprland.start` fires once, when the compositor comes up -- not on
-- `hyprctl reload`. It is the Lua equivalent of the old `exec-once`.

local apps = require("lua.apps")

hl.on("hyprland.start", function()
    -- Hand the session environment to systemd and D-Bus first, so services
    -- started below (and any portal launched on demand) inherit it.
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd " ..
        "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland HYPRLAND_INSTANCE_SIGNATURE"
    )

    -- Authentication agent, for anything asking for polkit privileges.
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Shell components.
    hl.exec_cmd(apps.bar)
    hl.exec_cmd("mako")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("batsignal")

    -- Wallpaper.
    --
    -- hyprpaper 0.8.4 does not read its config file on this system -- even a
    -- deliberately invalid key in hyprpaper.conf produces no error, and
    -- `preload`/`wallpaper` lines there are never applied. Setting it over IPC
    -- does work, so start hyprpaper, wait for its socket, then set it.
    -- (hyprpaper.conf is kept for when that is fixed upstream.)
    hl.exec_cmd(string.format([[
        hyprpaper &
        for _ in $(seq 1 50); do
            hyprctl hyprpaper listactive >/dev/null 2>&1 && break
            sleep 0.2
        done
        hyprctl hyprpaper wallpaper ",%s" >/dev/null 2>&1
    ]], apps.wallpaperImage))

    -- Clipboard history.
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Always start quiet; opt into Performance deliberately with SUPER+F2.
    hl.exec_cmd(apps.powerprofile .. " quiet")

    -- Idle handling: lock after 5 minutes, and on suspend.
    -- (The old config started this twice -- once here and once in idle.conf,
    -- which nothing ever sourced.)
    hl.exec_cmd("swayidle -w timeout 300 hyprlock before-sleep hyprlock lock hyprlock")

    -- Cursor theme for GTK applications. `cursor.sync_gsettings_theme` is on
    -- by default and usually covers this, but setting it explicitly costs
    -- nothing and survives other tools overwriting the value.
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-RosePine-Linux'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")

    -- Applications, each on its own workspace, without stealing focus.
    hl.exec_cmd(apps.terminal, { workspace = "1 silent" })
    hl.exec_cmd(apps.browser,  { workspace = "2 silent" })
    hl.exec_cmd(apps.music,    { workspace = "9 silent" })
    -- The old config passed `%U` to vesktop. That is a .desktop field code and
    -- means nothing on a command line -- vesktop received it as a literal
    -- argument.
    hl.exec_cmd(apps.chat,     { workspace = "10 silent" })
end)
