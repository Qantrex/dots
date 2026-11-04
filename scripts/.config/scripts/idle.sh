#!/usr/bin/env bash
# Idle handling for Hyprland (swayidle). Started once from autostart.lua.
#
#   4:30   dim to 10%                (any input restores the old brightness)
#   5:00   lock                      (hyprlock)
#   5:30   screen off                (OLED: a static lock screen must not stay lit)
#   15:00  suspend                   only on battery, and not while media plays
#
# The desktop (bauarch-pc) never suspends from here: it is the AI node, and
# only pc-guard may put it to sleep (Homelab/AI-Node.md). Before 2026-11-04 the
# battery check below read "no AC adapter" as "on battery", so the PC suspended
# after 15 idle minutes, even in the middle of an Ollama request. On the PC:
#   5:00   `away --idle`              lock + quiet mode (pc-quiet)
#   5:30   screens off
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
        if [[ $(cat /etc/hostname 2>/dev/null) == bauarch-pc ]]; then
            exec swayidle -w \
                timeout 300 "$HOME/.local/bin/away --idle" \
                timeout 330 "$(dpms off)" resume "$(dpms on)" \
                before-sleep 'loginctl lock-session; sleep 1' \
                after-resume "$(dpms on)" \
                lock "$LOCK"
        fi
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
        # Only machines with a battery suspend on idle.
        compgen -G '/sys/class/power_supply/BAT*' >/dev/null || exit 0
        [[ $(cat /sys/class/power_supply/A*/online 2>/dev/null) == 1 ]] && exit 0
        playerctl -a status 2>/dev/null | grep -qx Playing && exit 0
        systemctl suspend
        ;;
    *)
        echo "usage: ${0##*/} [suspend]" >&2
        exit 2
        ;;
esac
