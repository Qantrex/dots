#!/usr/bin/env bash
# Screenshot menu for Hyprland (wofi + grim + slurp)
# - Pick Region / Window / Monitor / All screens in wofi (styled by wofi/style.css)
# - Saves to ~/Pictures/Screenshots, copies to the clipboard, notifies
# - slurp's selection overlay uses the same true-black / white-border look

set -Eeuo pipefail

SHOT_DIR="${SHOT_DIR:-$HOME/Pictures/Screenshots}"

# slurp colours (RRGGBBAA): dimmed black backdrop, white 1px border,
# faint white fill -- the waybar panel look.
slurp_styled() {
  slurp -b '#000000a0' -c '#ffffffff' -s '#ffffff14' -B '#ffffff30' -w 1 "$@"
}

# Nerd Font glyphs, same font as wofi. Fixed order: no cache file.
choice="$(
  printf '%s\n' \
    "󰩭  Region" \
    "  Window" \
    "󰍹  Monitor" \
    "󰍺  All screens" |
  wofi --dmenu \
       --prompt "Screenshot" \
       --cache-file /dev/null \
       --width 320 \
       --lines 4
)" || exit 0

case "$choice" in
  *Region)
    geom="$(slurp_styled)" || exit 0
    ;;
  *Window)
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
  *Monitor)
    geom="$(slurp_styled -o)" || exit 0
    ;;
  *"All screens")
    geom=""
    ;;
  *) exit 0 ;;
esac

# Let wofi's surface fade out so it is not in the shot.
sleep 0.2

mkdir -p "$SHOT_DIR"
file="$SHOT_DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

if [[ -n "$geom" ]]; then
  grim -g "$geom" "$file"
else
  grim "$file"
fi

wl-copy --type image/png < "$file"
notify-send -t 2500 -i "$file" "Screenshot saved" "$(basename "$file") · copied to clipboard"
