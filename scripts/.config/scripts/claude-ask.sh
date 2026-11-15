#!/usr/bin/env bash
# SUPER+D: a quick-ask Claude window (Sonnet) on the special workspace "ask".
# It is started hidden at login (`claude-ask.sh --preload` in autostart.lua), so
# SUPER+D only shows or hides it and opens instantly. /clear starts a fresh
# conversation in place; /exit restarts Claude in the same window, so it stays
# ready. Closing the window ends it; the next SUPER+D starts it again.
# Costs about 340 MB of RAM while it waits, and no plan usage.
# It runs in ~/.local/share/claude-ask, whose CLAUDE.md (answer briefly, change
# nothing) and settings (no memory) live in ~/Projects/claude-config/ask.
# SUPER+SHIFT+D (`claude-ask.sh --clip`) starts a fresh question about whatever is on
# the clipboard, text or an image (SUPER+CTRL+S copies a screenshot region): the
# clipboard is saved to inbox/ and Claude reads it first. Inbox files go after 2 days.
# To get rid of it: delete this script, the SUPER+D and SUPER+SHIFT+D binds in
# keybinds.lua, the --preload line in autostart.lua and the "claude-ask" rule in rules.lua.

dir="$HOME/.local/share/claude-ask"

open() { hyprctl clients -j | jq -e 'any(.[]; .class == "claude-ask")' >/dev/null; }

# The claude process running in the window right now, if any.
running_claude() {
    local foot sh
    foot=$(hyprctl clients -j | jq -r 'first(.[] | select(.class == "claude-ask") | .pid) // empty')
    [[ -n $foot ]] || return
    for sh in $(pgrep -P "$foot"); do pgrep -P "$sh" -x claude; done | head -1
}

# Save the clipboard to inbox/ and leave the first prompt for the loop in .next.
save_clipboard() {
    local types f
    mkdir -p "$dir/inbox"
    find "$dir/inbox" -type f -mtime +1 -delete
    types=$(wl-paste --list-types 2>/dev/null)
    if grep -qx 'image/png' <<<"$types"; then
        f="inbox/clip-$(date +%Y%m%d-%H%M%S).png"
        wl-paste --type image/png > "$dir/$f"
    elif grep -q '^text/' <<<"$types" || grep -qx 'UTF8_STRING' <<<"$types"; then
        f="inbox/clip-$(date +%Y%m%d-%H%M%S).txt"
        wl-paste --no-newline > "$dir/$f"
    else
        notify-send -a Claude "Quick ask" "The clipboard is empty."
        return 1
    fi
    [[ -s $dir/$f ]] || { rm -f "$dir/$f"; notify-send -a Claude "Quick ask" "The clipboard is empty."; return 1; }
    printf '%s' "I copied something, saved at $f. Read it, say in one line what it is, then wait for my question." > "$dir/.next"
}

start() {
    # Started from inside another Claude session (a test, a `!` command), the
    # window would inherit that session's variables, e.g. the child-session
    # marker that turns transcript saving off. Never pass them on.
    local v
    for v in $(compgen -e | grep -E '^(CLAUDE|AI_AGENT)'); do unset "$v"; done

    # The loop restarts Claude after /exit; the sleep keeps a failing start
    # (no network, logged out) from spinning.
    foot --app-id=claude-ask --title="claude ask" \
        --working-directory="$dir" \
        sh -c 'while :; do
                   p=""; [ -f .next ] && { p=$(cat .next); rm -f .next; }
                   if [ -n "$p" ]; then "$HOME/.local/bin/claude" --model sonnet "$p"
                   else "$HOME/.local/bin/claude" --model sonnet; fi
                   sleep 1
               done' &
    for _ in $(seq 1 50); do
        open && return 0
        sleep 0.1
    done
}

if [[ $1 == --preload ]]; then
    open || start
    exit 0
fi

if [[ $1 == --clip ]]; then
    save_clipboard || exit 0
    if open; then
        # End the current question; the loop restarts Claude with the clipboard prompt.
        pid=$(running_claude)
        if [[ -n $pid ]]; then
            kill -TERM "$pid"
            for _ in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
            kill -KILL "$pid" 2>/dev/null
        fi
    else
        start
    fi
    # Show it (only toggle when it's hidden).
    if [[ $(hyprctl activeworkspace -j | jq -r .name) != special:ask ]] &&
       ! hyprctl monitors -j | jq -e 'any(.[]; .specialWorkspace.name == "special:ask")' >/dev/null; then
        hyprctl dispatch 'hl.dsp.workspace.toggle_special("ask")' >/dev/null
    fi
    exit 0
fi

if ! open; then
    start
fi
hyprctl dispatch 'hl.dsp.workspace.toggle_special("ask")' >/dev/null
