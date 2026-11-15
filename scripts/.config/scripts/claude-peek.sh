#!/usr/bin/env bash
# Answer a Claude session without leaving the workspace you're on: a floating terminal on
# the special workspace "peek" shows that session's real tmux window, over whatever runs
# (a video, the browser). Answer there, then SUPER+SHIFT+A hides it again.
#   claude-peek.sh <session id>   show that session
#   claude-peek.sh --first        the session that has waited longest
#   claude-peek.sh --toggle       SUPER+SHIFT+A: hide when shown; else the longest-waiting
#                                 session, else whatever the window showed last
# It uses a tmux session "peek" grouped with the main one: same windows, but its own
# current window, so the terminal on workspace 1 keeps showing what it showed. tmux
# resizes a window to the client used last, so the main terminal reflows once on return.
# Sessions come from ~/.local/state/claude-sessions (session-track.sh in claude-config).
# Only sessions inside tmux can be shown.

state="${XDG_STATE_HOME:-$HOME/.local/state}/claude-sessions"
summary="${XDG_CACHE_HOME:-$HOME/.cache}/claude-waiting.json"

window_open() { hyprctl clients -j | jq -e 'any(.[]; .class == "claude-peek")' >/dev/null; }
shown() { hyprctl monitors -j | jq -e 'any(.[]; .specialWorkspace.name == "special:peek")' >/dev/null; }
toggle() { hyprctl dispatch 'hl.dsp.workspace.toggle_special("peek")' >/dev/null; }
say() { notify-send -a Claude "Claude" "$1"; }

id=""
case $1 in
--toggle)
    if shown; then toggle; exit 0; fi
    id=$(jq -r '.[0].id // empty' "$summary" 2>/dev/null)
    if [[ -z $id ]]; then
        if window_open && tmux has-session -t peek 2>/dev/null; then toggle; else say "No session is waiting."; fi
        exit 0
    fi ;;
--first)
    id=$(jq -r '.[0].id // empty' "$summary" 2>/dev/null)
    [[ -n $id ]] || { say "No session is waiting."; exit 0; } ;;
*) id=$1 ;;
esac

rec="$state/$id.json"
[[ -n $id && -f $rec ]] || { say "That session isn't open any more."; exit 1; }
pane=$(jq -r '.pane // empty' "$rec")
if [[ -z $pane ]] || ! tmux display -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; then
    # Not in tmux (a plain foot window): the best we can do is go there.
    exec "$HOME/.config/scripts/claude-jump.sh" "$id"
fi
target_session=$(tmux display -p -t "$pane" '#{session_name}')
window=$(tmux display -p -t "$pane" '#{window_id}')

# The grouped session lives only as long as the peek window (destroy-unattached), so a
# new terminal's `tmux attach` never lands in it. Recreate both when the group changes.
group=$(tmux display -p -t "$target_session" '#{?session_grouped,#{session_group},#{session_name}}')
if window_open && tmux has-session -t peek 2>/dev/null &&
   [[ $(tmux display -p -t peek: '#{session_group}') == "$group" ]]; then
    tmux select-window -t "peek:$window"
    tmux select-pane -t "$pane"
else
    hyprctl clients -j | jq -r '.[] | select(.class == "claude-peek") | .pid' | xargs -r kill
    tmux kill-session -t peek 2>/dev/null
    foot --app-id=claude-peek --title="claude peek" \
        tmux new-session -s peek -t "$target_session" \; set-option destroy-unattached on \; \
        select-window -t "$window" \; select-pane -t "$pane" >/dev/null 2>&1 &
    disown
    for _ in $(seq 1 50); do window_open && break; sleep 0.1; done
fi
shown || toggle
hyprctl dispatch 'hl.dsp.focus({ window = "class:^(claude-peek)$" })' >/dev/null
