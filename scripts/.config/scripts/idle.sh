#!/usr/bin/env bash
# Idle handling for Hyprland (swayidle). Started once from autostart.lua.
#
#   4:30   dim to 10%                (any input restores the old brightness)
#   5:00   lock                      (hyprlock)
#   5:30   screen off                (OLED: a static lock screen must not stay lit)
#   15:00  suspend                   only on battery, and not while media plays
#
# Anything that inhibits idle -- a video playing in Firefox or mpv -- holds all
# of it off. Suspending for any reason (lid, idle, menu) locks first.
#
# The old one-liner (`swayidle -w timeout 300 hyprlock ...`) only locked: it
# had no screen-off step, so the lock screen stayed lit on the OLED panel
# indefinitely, and nothing ever suspended on idle.
#
# Usage:
#   idle.sh           start swayidle (autostart)
#   idle.sh suspend   the 15-minute step: suspend if on battery and nothing plays

set -uo pipefail

readonly LOCK='pidof hyprlock >/dev/null || hyprlock'

dpms() { printf "hyprctl dispatch 'hl.dsp.dpms({ action = \"%s\" })' >/dev/null" "$1"; }

case "${1:-start}" in
    start)
        exec swayidle -w \
            timeout 270 'brightnessctl -q -s set 10%' resume 'brightnessctl -q -r' \
            timeout 300 "$LOCK" \
            timeout 330 "$(dpms off)" resume "$(dpms on)" \
            timeout 900 "$0 suspend" \
            before-sleep 'loginctl lock-session; sleep 1' \
            after-resume "$(dpms on)" \
            lock "$LOCK"
        ;;
    suspend)
        [[ $(cat /sys/class/power_supply/A*/online 2>/dev/null) == 1 ]] && exit 0
        playerctl -a status 2>/dev/null | grep -qx Playing && exit 0
        systemctl suspend
        ;;
    *)
        echo "usage: ${0##*/} [suspend]" >&2
        exit 2
        ;;
esac
