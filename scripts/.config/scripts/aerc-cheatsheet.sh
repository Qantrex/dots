#!/usr/bin/env bash
# Toggle the aerc cheatsheet (~/.config/aerc/cheatsheet.txt) next to aerc.
#
# It is a plain foot + less window, so it costs a few MB while open and nothing
# once closed. A window rule in rules.lua puts it on workspace 8 with aerc, and
# a window.open hook there runs `aerc-cheatsheet.sh arrange <class>` whenever
# aerc or the sheet opens, so the layout holds whichever one comes first.
# To get rid of it: delete this script, the SUPER+H bind in keybinds.lua and the
# "mail-cheatsheet-to-workspace-8" rule plus the window.open hook in rules.lua.

# Put the sheet on the right, narrowed to the text width, next to aerc.
# $1 is the class of the window that just opened; it gets focus back at the end.
arrange() {
    local opened=$1 i

    # Both have to be mapped and tiled; the hook fires as the window opens.
    for i in $(seq 1 30); do
        [[ $(hyprctl clients | grep -cE "class: aerc(-cheat)?$") -ge 2 ]] && break
        sleep 0.1
    done
    (( i == 30 )) && return 0
    sleep 0.1

    # splitratio acts on the focused window's split. 1.28 gives the left side
    # 64%, which leaves the sheet ~48 columns at font size 12 (the longest line
    # is 47); retune if the font or text changes.
    hyprctl dispatch 'hl.dsp.focus({ window = "class:^(aerc-cheat)$" })' >/dev/null
    hyprctl dispatch 'hl.dsp.layout("splitratio 1.28 exact")' >/dev/null

    # Dwindle opens new windows on the side the mouse is on. Keep the sheet on
    # the right; the sizes stay with the sides, so aerc keeps the wide one.
    local aerc_x sheet_x
    aerc_x=$(x_of aerc) sheet_x=$(x_of aerc-cheat)
    if [[ -n $aerc_x && -n $sheet_x ]] && (( sheet_x < aerc_x )); then
        hyprctl dispatch 'hl.dsp.window.swap({ direction = "right" })' >/dev/null
    fi

    [[ -n $opened ]] &&
        hyprctl dispatch "hl.dsp.focus({ window = \"class:^($opened)\$\" })" >/dev/null
}

x_of() { hyprctl clients -j | jq ".[] | select(.class == \"$1\") | .at[0]" | head -1; }

if [[ $1 == arrange ]]; then
    arrange "$2"
    exit 0
fi

# Anchored, so it only matches the cheatsheet's own foot process.
if pkill -f -- "^foot --app-id=aerc-cheat "; then
    exit 0
fi

# The window.open hook arranges it once it appears.
foot --app-id=aerc-cheat --title="aerc cheatsheet" \
    less -S ~/.config/aerc/cheatsheet.txt &
