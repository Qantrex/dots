#!/usr/bin/env bash
# Idle handling for Hyprland (swayidle). Started once from autostart.lua.
#
#   4:30   dim to 10%                (any input restores the old brightness)
#   5:00   lock                      (agentic-lock: the Quickshell lock in root-agentic,
#                                     hyprlock in every other theme and as its fallback)
#   5:30   screen off                (OLED: a static lock screen must not stay lit)
#   15:00  suspend                   only on battery, and not while media plays
#
# The desktop (bauarch-pc) never suspends from here: it is the AI node, and
# only pc-guard may put it to sleep (Homelab/AI-Node.md). Before 2026-11-04 the
# battery check below read "no AC adapter" as "on battery", so the PC suspended
# after 15 idle minutes, even in the middle of an Ollama request. On the PC:
#   5:00   `away --idle`              lock + quiet mode (pc-quiet)
#   5:30   screens off
# The PC keeps hyprlock until the Quickshell lock has passed its check there: the check writes
# ~/.local/state/agentic/lock-checked, and from then on `away` and the lock event use agentic-lock
# (agentic-os.md, stage 3). `away` runs in the background like the laptop's lock: it waits for the unlock,
# and with -w that held swayidle up, so the screens stayed lit for as long as the PC was locked (seen on
# 2026-11-20: locked for three hours, both screens on).
#
# Anything that inhibits idle -- a video playing in Firefox or mpv -- holds all
# of it off. Suspending for any reason (lid, idle, menu) locks first.
#
# Locking never holds swayidle up (2026-11-19). With -w swayidle waits for every command, and the lock
# runs until I unlock: while locked the screen never went off, the steps that came due meanwhile (screen
# off, the 15-minute suspend) all ran right after the unlock, and a lock asked for by before-sleep only
# started after before-sleep had ended, so the laptop went to sleep while the lock was still being built
# and on resume hyprlock took over from it (the "flash", 23:16). Now the lock runs in the background, and
# before-sleep starts it itself and waits until it is up. -w stays: it makes swayidle wait for that.
#
# The old one-liner (`swayidle -w timeout 300 hyprlock ...`) only locked: it
# had no screen-off step, so the lock screen stayed lit on the OLED panel
# indefinitely, and nothing ever suspended on idle.
#
# Usage:
#   idle.sh           start swayidle (autostart)
#   idle.sh suspend   the 15-minute step: suspend if on battery and nothing plays
#   idle.sh before-sleep   lock and wait until the lock is up

set -uo pipefail

# swayidle runs with Hyprland's environment, which has no ~/.local/bin on PATH. agentic-lock does
# nothing when either lock is already up.
readonly LOCK="$HOME/.local/bin/agentic-lock"

dpms() { printf "hyprctl dispatch 'hl.dsp.dpms({ action = \"%s\" })' >/dev/null" "$1"; }

case "${1:-start}" in
    start)
        if [[ $(cat /etc/hostname 2>/dev/null) == bauarch-pc ]]; then
            pc_lock='pidof hyprlock >/dev/null || hyprlock &'
            pc_sleep='pidof hyprlock >/dev/null || hyprlock & sleep 1'
            if [[ -e ${XDG_STATE_HOME:-$HOME/.local/state}/agentic/lock-checked ]]; then
                pc_lock="$LOCK &"; pc_sleep="$0 before-sleep"
            fi
            exec swayidle -w \
                timeout 300 "$HOME/.local/bin/away --idle &" \
                timeout 330 "$(dpms off)" resume "$(dpms on)" \
                before-sleep "$pc_sleep" \
                after-resume "$(dpms on)" \
                lock "$pc_lock"
        fi
        exec swayidle -w \
            timeout 270 'brightnessctl -q -s set 10%' resume 'brightnessctl -q -r' \
            timeout 300 "$LOCK &" \
            timeout 330 "$(dpms off)" resume "$(dpms on)" \
            timeout 900 "$0 suspend" \
            before-sleep "$0 before-sleep" \
            after-resume "$(dpms on)" \
            lock "$LOCK &"
        ;;
    before-sleep)
        # Lock, then wait (at most 3 s) until the compositor has confirmed it: the Quickshell lock logs
        # "locked"; hyprlock (other themes, the fallback) says nothing, so its old second. Matching the
        # process first keeps an earlier lock's log from counting.
        "$LOCK" >/dev/null 2>&1 &
        log="${XDG_CACHE_HOME:-$HOME/.cache}/agentic/lock.log"
        end=$((SECONDS + 3))
        while ((SECONDS < end)); do
            if pgrep -u "$UID" -f "^qs -p $HOME/.config/quickshell/lock\$" >/dev/null &&
                grep -qF 'agentic-lock: locked' "$log" 2>/dev/null; then
                exit 0
            fi
            pidof hyprlock >/dev/null && { sleep 1; exit 0; }
            sleep 0.1
        done
        ;;
    suspend)
        # Only machines with a battery suspend on idle.
        compgen -G '/sys/class/power_supply/BAT*' >/dev/null || exit 0
        [[ $(cat /sys/class/power_supply/A*/online 2>/dev/null) == 1 ]] && exit 0
        playerctl -a status 2>/dev/null | grep -qx Playing && exit 0
        systemctl suspend
        ;;
    *)
        echo "usage: ${0##*/} [suspend|before-sleep]" >&2
        exit 2
        ;;
esac
