#!/usr/bin/env bash
# The desktop shell (Quickshell: bar, notifications, OSD, launcher) under a
# small supervisor, so a crash doesn't silently leave the session without a bar
# and without a notification daemon.
#
# Usage:
#   shell.sh [start]   run qs and restart it whenever it exits (autostart)
#   shell.sh restart   restart qs (SUPER+SHIFT+R, hyprr); starts the
#                      supervisor if none is running
#
# One supervisor per session (a lock in $XDG_RUNTIME_DIR). It ends with the
# Hyprland session. After 5 quick deaths in a row (each within 30 s of its
# start) it waits a minute before trying again instead of spinning. qs logs:
# `qs log`.
set -uo pipefail

LOCK="${XDG_RUNTIME_DIR:-/tmp}/qs-supervisor.lock"

case "${1:-start}" in
  start)
    exec 9>"$LOCK"
    flock -n 9 || exit 0
    fails=0
    while :; do
      started=$(date +%s)
      qs -n                        # -n: exits at once if another qs runs this config
      pgrep -x Hyprland >/dev/null || exit 0
      if (( $(date +%s) - started < 30 )); then fails=$((fails + 1)); else fails=0; fi
      if (( fails >= 5 )); then
        sleep 60
        fails=0
      else
        sleep 1
      fi
    done
    ;;
  restart)
    pkill -x qs
    # A free lock means no supervisor: start one (it starts qs).
    if flock -n "$LOCK" true; then
      setsid -f "$0" start >/dev/null 2>&1
    fi
    ;;
  *)
    echo "usage: $(basename "$0") [start|restart]" >&2
    exit 2
    ;;
esac
