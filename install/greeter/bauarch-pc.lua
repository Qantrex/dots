-- Login screen for bauarch-pc: tuigreet in a tiny Hyprland, so it shows on the
-- main monitor only and at a readable size. The kernel console can do neither:
-- it mirrors to every monitor in a small font.
-- Installed to /etc/greetd/hyprland-greeter.lua by setup_greetd in install/lib.sh.

hl.monitor({
    output   = "desc:AOC Q27G2G4",
    mode     = "2560x1440@144",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
    output   = "desc:AOC 27G2G8",
    disabled = true,
})

hl.config({
    animations = { enabled = false },
    input = { kb_layout = "de" },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        disable_watchdog_warning = true,
    },
})

-- The login only completes once this compositor exits, so stop it when tuigreet ends.
hl.on("hyprland.start", function()
    hl.exec_cmd([[foot -c /dev/null -F -o "font=JetBrainsMono Nerd Font:size=16" -o colors-dark.background=000000 sh -c "tuigreet --time --remember --asterisks --cmd start-hyprland; pkill -x -u greeter Hyprland"]])
end)
