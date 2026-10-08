#!/usr/bin/env bash
# Thumbnail wallpaper picker for Hyprland (wofi + hyprpaper)
# - Shows image grid (thumbnails) in wofi
# - Sets wallpaper via hyprpaper IPC (`hyprctl hyprpaper wallpaper`)
# - Applies to all monitors by default, or a chosen one

set -Eeuo pipefail
IFS=$'\n\t'

# ----------------------- Config (tweakables) -----------------------
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
THUMB_W="${THUMB_W:-520}"                     # px, thumbnails are 16:9
THUMB_H="${THUMB_H:-293}"
WOFI_COLUMNS="${WOFI_COLUMNS:-2}"             # not COLUMNS: shells set that to the terminal width
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/wofi-wallpapers"
THUMB_DIR="$CACHE_ROOT/thumbs"
CACHE_FILE="$CACHE_ROOT/wofi-cache"           # wofi cache file
# ------------------------------------------------------------------

script_path="$(readlink -f "$0")"

die() { echo "Error: $*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Pick a thumbnailer (vips is fastest, else ImageMagick)
pick_thumb_tool() {
  if have vipsthumbnail; then echo "vipsthumbnail"; return; fi
  if have magick;       then echo "magick";       return; fi
  if have convert;      then echo "convert";      return; fi
  die "Need 'vipsthumbnail' or ImageMagick ('magick'/'convert') for thumbnails."
}

THUMBER="$(pick_thumb_tool)"

# Render helper: given a path, emit "img:<thumb>" (image only, no label)
render_entry() {
  local src="$1"
  # Hash path into a stable thumbnail name
  local hash; hash="$(printf "%s" "$src" | sha1sum | cut -d' ' -f1)"
  local out="$THUMB_DIR/${hash}.jpg"
  mkdir -p "$THUMB_DIR"

  if [[ ! -s "$out" || "$src" -nt "$out" ]]; then
    case "$THUMBER" in
      vipsthumbnail)
        # Center-crop to 16:9
        vipsthumbnail "$src" -s "${THUMB_W}x${THUMB_H}" --smartcrop centre -o "$out" >/dev/null 2>&1 || true
        ;;
      magick)
        magick "$src" -auto-orient -thumbnail "${THUMB_W}x${THUMB_H}^" \
               -gravity center -extent "${THUMB_W}x${THUMB_H}" -strip "$out" >/dev/null 2>&1 || true
        ;;
      convert)
        convert "$src" -auto-orient -thumbnail "${THUMB_W}x${THUMB_H}^" \
                -gravity center -extent "${THUMB_W}x${THUMB_H}" -strip "$out" >/dev/null 2>&1 || true
        ;;
    esac
    # Fallback: if thumbnail failed, symlink to source (wofi will try to render it)
    [[ -s "$out" ]] || ln -sf "$src" "$out"
  fi

  # Display is the thumbnail only; output of wofi remains the original line
  # No trailing newline: wofi would read it as part of the image path
  printf 'img:%s' "$out"
}

# Mode: pre-display transformer for wofi
if [[ "${1-}" == "--render" && -n "${2-}" ]]; then
  render_entry "$2"
  exit 0
fi

# CLI args
TARGET_MONITOR="all"
while (( $# )); do
  case "$1" in
    -d|--dir)     WALLPAPER_DIR="${2:?}"; shift 2;;
    -m|--monitor) TARGET_MONITOR="${2:?}"; shift 2;;  # e.g. eDP-1, HDMI-A-1, or "all"
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [-d DIR] [-m MONITOR]
  -d, --dir       Wallpaper directory (default: $WALLPAPER_DIR)
  -m, --monitor   Monitor name (hyprctl monitors -j), or "all" (default)
EOF
      exit 0
      ;;
    *) die "Unknown arg: $1";;
  esac
done

[[ -d "$WALLPAPER_DIR" ]] || die "Wallpaper dir not found: $WALLPAPER_DIR"

# Ensure hyprpaper is running (quietly start if not)
if ! pgrep -x hyprpaper >/dev/null 2>&1; then
  # Prefer running with IPC enabled (default in recent hyprpaper)
  ( hyprpaper >/dev/null 2>&1 & disown ) || die "Failed to start hyprpaper"
  # wait (up to ~2s) for its IPC socket to come up
  for _ in $(seq 20); do
    hyprctl hyprpaper listactive >/dev/null 2>&1 && break
    sleep 0.1
  done
fi

# Build image list (absolute paths) safely
mapfile -d '' -t IMAGES < <(
  find "$WALLPAPER_DIR" -type f \
    -iregex '.*\.\(jpe\?g\|png\|webp\|gif\|bmp\|avif\)$' \
    -print0
)


(( ${#IMAGES[@]} )) || die "No images found in: $WALLPAPER_DIR"

mkdir -p "$CACHE_ROOT"

# Show wofi with thumbnails:
# - We pass the **full paths** to wofi.
# - pre-display-cmd calls this script with --render to turn each line into a thumbnail entry.
# - Output from wofi remains the unmodified full path.
SEL="$(
  printf '%s\n' "${IMAGES[@]}" | \
  wofi --dmenu \
       --allow-images \
       --pre-display-cmd "$script_path --render %s" \
       --define "image_size=$THUMB_W" \
       --columns "$WOFI_COLUMNS" \
       --width $(( (THUMB_W + 28) * WOFI_COLUMNS + 24 )) \
       --height 760 \
       --hide-search \
       --cache-file "$CACHE_FILE"
)"

# User canceled
[[ -n "${SEL// }" ]] || { echo "Canceled."; exit 0; }

# hyprpaper wants absolute paths; ensure we have one
SEL_ABS="$(readlink -f -- "$SEL")" || SEL_ABS="$SEL"

# Apply wallpaper:
# - hyprpaper 0.8 removed the `reload`/`preload`/`unload` requests;
#   `wallpaper` now loads and sets in one step.
# - ",PATH" applies to all monitors; otherwise we set monitor,PATH
if [[ "$TARGET_MONITOR" == "all" ]]; then
  hyprctl -q hyprpaper wallpaper ",$SEL_ABS" || die "hyprpaper wallpaper failed"
else
  hyprctl -q hyprpaper wallpaper "$TARGET_MONITOR,$SEL_ABS" || die "hyprpaper wallpaper failed for $TARGET_MONITOR"
fi

# Persist last choice
echo "$SEL_ABS" > "$CACHE_ROOT/last"

notify-send -t 1500 "Wallpaper updated" "$(basename "$SEL_ABS")"
echo "Wallpaper set: $SEL_ABS"
