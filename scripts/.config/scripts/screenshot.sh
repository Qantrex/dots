#!/usr/bin/env bash
# Screenshots for Hyprland (grim + slurp). The launcher's screenshot mode
# (SUPER+SHIFT+S) and SUPER+CTRL+S call this.
#
# Usage: screenshot.sh [region|window|monitor|all]   (default: region)
# Saves to ~/Pictures/Screenshots, copies to the clipboard, notifies.
# slurp's selection uses the shell's look: dimmed black, white 1px border.

set -Eeuo pipefail

SHOT_DIR="${SHOT_DIR:-$HOME/Pictures/Screenshots}"

slurp_styled() {
  slurp -b '#000000a0' -c '#ffffffff' -s '#ffffff14' -B '#ffffff30' -w 1 "$@"
}

case "${1:-region}" in
  region)
    geom="$(slurp_styled)" || exit 0
    ;;
  window)
    # Visible windows on the active workspace of each monitor, as slurp boxes.
    ws="$(hyprctl monitors -j | jq -r '[.[].activeWorkspace.id] | join(",")')"
    geom="$(
      hyprctl clients -j |
        jq -r --argjson ws "[$ws]" \
          '.[] | select(.mapped and (.hidden | not) and (.workspace.id as $w | $ws | index($w)))
               | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' |
        slurp_styled -r
    )" || exit 0
    ;;
  monitor)
    geom="$(slurp_styled -o)" || exit 0
    ;;
  all)
    geom=""
    ;;
  *)
    echo "usage: $(basename "$0") [region|window|monitor|all]" >&2
    exit 2
    ;;
esac

mkdir -p "$SHOT_DIR"
file="$SHOT_DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

if [[ -n "$geom" ]]; then
  grim -g "$geom" "$file"
else
  grim "$file"
fi

wl-copy --type image/png < "$file"
notify-send -t 2500 -i "$file" "Screenshot saved" "$(basename "$file") · copied to clipboard"
