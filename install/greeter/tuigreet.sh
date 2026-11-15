#!/bin/sh
# tuigreet with the desktop's look: black, greys, white input. Installed to
# /etc/greetd/tuigreet.sh by scripts/setup-boot-style.sh; greetd runs it
# directly (laptop, kernel console) or inside the small Hyprland greeter
# (install/greeter/<host>.lua). One place for the flags, both machines.
#
# Colours are the 16 console colour names. On the kernel console they come
# from the vt.default_* palette on the kernel command line (also set by
# setup-boot-style.sh): gray = #d0d0d0, darkgray = #7a7a7a, white = #ffffff.
#
# Plain black around the box, no animated background: the DOOM fire and matrix
# rain were removed on 2026-11-15 as decoration that imitated nothing real.

session=Hyprland
[ -x /usr/bin/start-hyprland ] && session=start-hyprland

exec tuigreet \
    --cmd "$session" \
    --remember --asterisks \
    --time --time-format '%H:%M  %a %d %b' \
    --greeting "Arch Linux  ·  $(cat /etc/hostname 2>/dev/null)" \
    --width 56 --window-padding 2 --container-padding 2 \
    --theme 'border=darkgray;title=gray;text=gray;greet=white;prompt=white;input=white;time=darkgray;action=white;button=white;container=black' \
    "$@"
