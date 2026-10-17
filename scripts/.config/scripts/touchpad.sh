#!/usr/bin/env bash
# Touchpad on/off, behind Fn+F6 and the waybar icon.
#
# Fn+F6 arrives as KEY_TOUCHPAD_TOGGLE (XF86TouchpadToggle) from "Asus WMI
# hotkeys"; the firmware leaves the touchpad itself alone, so this does the
# switching. Hyprland can't report whether a device is enabled, so the state
# lives in a file (present = off). input.lua reads the same file, so a config
# reload or restart leaves the touchpad the way it was.
#
# Usage:
#   touchpad.sh toggle   on <-> off   (Fn+F6, click)
#   touchpad.sh on|off   set it
#   touchpad.sh get      print on/off
#   touchpad.sh status   print waybar JSON

set -uo pipefail

# Keep in sync with input.lua.
readonly STATE_FILE=$HOME/.local/state/touchpad-off
readonly WAYBAR_SIGNAL=10
# hid-multitouch exposes the pad as two nodes; the mouse one is a fallback the
# pad only uses outside precision-touchpad mode. Both go off together.
readonly DEVICES=(asue1a00:00-04f3:31de-touchpad asue1a00:00-04f3:31de-mouse)

current() { [[ -e $STATE_FILE ]] && echo off || echo on; }

icon_for() {
    case $1 in
        on)  printf '󰍽' ;;   # mouse
        off) printf '󰍾' ;;   # mouse-off
    esac
}

refresh_waybar() { pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null || true; }

set_state() {
    local want=$1 enabled=true lua="" d
    [[ $want == off ]] && enabled=false
    for d in "${DEVICES[@]}"; do
        lua+="hl.device({ name = \"$d\", enabled = $enabled }) "
    done
    # Only record the new state once Hyprland has accepted it, so the icon
    # never claims something that didn't happen.
    if [[ $(hyprctl eval "$lua" 2>&1) != ok ]]; then
        echo "touchpad: hyprctl eval failed (is Hyprland running?)" >&2
        return 1
    fi
    if [[ $want == off ]]; then
        mkdir -p "${STATE_FILE%/*}" && : >"$STATE_FILE"
    else
        rm -f "$STATE_FILE"
    fi

    refresh_waybar
    notify-send -a "Touchpad" -t 2000 \
        -h "string:x-canonical-private-synchronous:touchpad" \
        "$(icon_for "$want")  Touchpad ${want}" 2>/dev/null || true
}

status_json() {
    local s; s=$(current)
    printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s"}\n' \
        "$(icon_for "$s")" "$s" "$s" "Touchpad: ${s}\n\nClick or Fn+F6: toggle"
}

case "${1:-status}" in
    on|off) set_state "$1" ;;
    toggle)
        if [[ $(current) == on ]]; then set_state off; else set_state on; fi
        ;;
    get)    current ;;
    status) status_json ;;
    *)
        echo "usage: ${0##*/} {toggle|on|off|get|status}" >&2
        exit 2
        ;;
esac
