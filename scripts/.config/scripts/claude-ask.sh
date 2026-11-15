#!/usr/bin/env bash
# SUPER+D: a quick-ask Claude window (Sonnet) on the special workspace "ask".
# It is started hidden at login (`claude-ask.sh --preload` in autostart.lua), so
# SUPER+D only shows or hides it and opens instantly. /clear starts a fresh
# conversation in place; /exit restarts Claude in the same window, so it stays
# ready. Closing the window ends it; the next SUPER+D starts it again.
# Costs about 340 MB of RAM while it waits, and no plan usage.
# It runs in ~/.local/share/claude-ask, whose CLAUDE.md (answer briefly, change
# nothing) and settings (no memory) live in ~/Projects/claude-config/ask.
# To get rid of it: delete this script, the SUPER+D bind in keybinds.lua, the
# --preload line in autostart.lua and the "claude-ask" rule in rules.lua.

open() { hyprctl clients -j | jq -e 'any(.[]; .class == "claude-ask")' >/dev/null; }

start() {
    # Started from inside another Claude session (a test, a `!` command), the
    # window would inherit that session's variables, e.g. the child-session
    # marker that turns transcript saving off. Never pass them on.
    local v
    for v in $(compgen -e | grep -E '^(CLAUDE|AI_AGENT)'); do unset "$v"; done

    # The loop restarts Claude after /exit; the sleep keeps a failing start
    # (no network, logged out) from spinning.
    foot --app-id=claude-ask --title="claude ask" \
        --working-directory="$HOME/.local/share/claude-ask" \
        sh -c 'while :; do "$HOME/.local/bin/claude" --model sonnet; sleep 1; done' &
    for _ in $(seq 1 50); do
        open && return 0
        sleep 0.1
    done
}

if [[ $1 == --preload ]]; then
    open || start
    exit 0
fi

if ! open; then
    start
fi
hyprctl dispatch 'hl.dsp.workspace.toggle_special("ask")' >/dev/null
