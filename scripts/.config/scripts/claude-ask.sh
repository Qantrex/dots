#!/usr/bin/env bash
# SUPER+D: a quick-ask Claude window (Sonnet) on the special workspace "ask".
# The first press opens it; later presses show or hide it, so a follow-up
# question still has the context. Closing the window (or /exit) ends that
# conversation, and the next press starts a fresh one.
# It runs in ~/.local/share/claude-ask, whose CLAUDE.md (answer briefly, change
# nothing) and settings (no memory) live in ~/Projects/claude-config/ask.
# To get rid of it: delete this script, the SUPER+D bind in keybinds.lua and the
# "claude-ask" rule in rules.lua.

open() { hyprctl clients -j | jq -e 'any(.[]; .class == "claude-ask")' >/dev/null; }

if open; then
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("ask")' >/dev/null
    exit 0
fi

foot --app-id=claude-ask --title="claude ask" \
    --working-directory="$HOME/.local/share/claude-ask" \
    "$HOME/.local/bin/claude" --model sonnet &

# The rule opens it silently on special:ask; show that workspace once it exists.
for _ in $(seq 1 30); do
    open && break
    sleep 0.1
done
hyprctl dispatch 'hl.dsp.workspace.toggle_special("ask")' >/dev/null
