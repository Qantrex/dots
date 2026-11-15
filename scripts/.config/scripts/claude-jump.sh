#!/usr/bin/env bash
# Bring a Claude session to the front: its tmux window and pane, and the foot window that
# shows it. Used by the "waiting" notifications and the bar flag (session-track.sh in
# ~/Projects/claude-config keeps the records).
#   claude-jump.sh <session id>   that session
#   claude-jump.sh --first        the session that has waited longest
#   claude-jump.sh --clear        forget all waiting marks (the bar flag goes away)

state="${XDG_STATE_HOME:-$HOME/.local/state}/claude-sessions"
summary="${XDG_CACHE_HOME:-$HOME/.cache}/claude-waiting.json"

foot_of() {
    local p=$1
    while [[ -n $p && $p != 1 && $p != 0 ]]; do
        [[ $(cat /proc/"$p"/comm 2>/dev/null) == foot ]] && { echo "$p"; return; }
        p=$(awk '/^PPid:/{print $2}' /proc/"$p"/status 2>/dev/null)
    done
}

case $1 in
--clear)
    for r in "$state"/*.json; do
        [[ -f $r ]] && grep -q '"waiting"' "$r" && jq 'del(.waiting, .why)' "$r" > "$r.tmp" && mv -f "$r.tmp" "$r"
    done
    echo '[]' > "$summary"
    exit 0 ;;
--first) id=$(jq -r '.[0].id // empty' "$summary" 2>/dev/null) ;;
*) id=$1 ;;
esac
rec="$state/$id.json"
[[ -n $id && -f $rec ]] || { notify-send -a Claude "Claude" "That session isn't open any more."; exit 1; }

pane=$(jq -r '.pane // empty' "$rec")
pid=$(jq -r .pid "$rec")
win=""
if [[ -n $pane ]] && tmux display -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; then
    # Show the pane in a client that is already attached, preferring one on its own session.
    session=$(tmux display -p -t "$pane" '#{session_name}')
    client=$(tmux list-clients -t "$session" -F '#{client_pid} #{client_name}' 2>/dev/null | head -1)
    [[ -n $client ]] || client=$(tmux list-clients -F '#{client_pid} #{client_name}' | head -1)
    if [[ -n $client ]]; then
        tmux switch-client -c "${client#* }" -t "$pane"
        tmux select-window -t "$pane"
        tmux select-pane -t "$pane"
        win=$(foot_of "${client%% *}")
    fi
else
    win=$(foot_of "$pid")
fi

if [[ -n $win ]]; then
    hyprctl dispatch "hl.dsp.focus({ window = \"pid:$win\" })" >/dev/null
else
    # Detached tmux session, no terminal shows it: open one on it.
    [[ -n $pane ]] && setsid -f foot tmux attach -t "$pane" >/dev/null 2>&1
fi
