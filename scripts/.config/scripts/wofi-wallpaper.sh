#!/usr/bin/env bash
# Thumbnail wallpaper picker for Hyprland (wofi + hyprpaper)
# - Shows image grid (thumbnails) in wofi
# - Sets wallpaper via hyprpaper reload (fast, low-memory)
# - Applies to all monitors by default, or a chosen one

set -Eeuo pipefail
IFS=$'\n\t'

# ----------------------- Config (tweakables) -----------------------
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
THUMB_SIZE="${THUMB_SIZE:-256}"               # px, square
COLUMNS="${COLUMNS:-2}"                       # wofi columns
IMAGE_GLOBS="${IMAGE_GLOBS:-jpg jpeg png webp gif bmp avif}"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/wofi-wallpapers"
THUMB_DIR="$CACHE_ROOT/thumbs"
CACHE_FILE="$CACHE_ROOT/wofi-cache"           # wofi cache file
WOFI_PROMPT="${WOFI_PROMPT:-Select wallpaper}"
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

# Render helper: given a path, emit "img:<thumb>:text:<label>"
render_entry() {
  local src="$1"
  # Hash path into a stable thumbnail name
  local hash; hash="$(printf "%s" "$src" | sha1sum | cut -d' ' -f1)"
  local out="$THUMB_DIR/${hash}.jpg"
  mkdir -p "$THUMB_DIR"

  if [[ ! -s "$out" || "$src" -nt "$out" ]]; then
    case "$THUMBER" in
      vipsthumbnail)
        # Center-crop square
        vipsthumbnail "$src" -s "${THUMB_SIZE}x${THUMB_SIZE}" -o "$out" >/dev/null 2>&1 || true
        ;;
      magick)
        magick "$src" -auto-orient -thumbnail "${THUMB_SIZE}x${THUMB_SIZE}^" \
               -gravity center -extent "${THUMB_SIZE}x${THUMB_SIZE}" -strip "$out" >/dev/null 2>&1 || true
        ;;
      convert)
        convert "$src" -auto-orient -thumbnail "${THUMB_SIZE}x${THUMB_SIZE}^" \
                -gravity center -extent "${THUMB_SIZE}x${THUMB_SIZE}" -strip "$out" >/dev/null 2>&1 || true
        ;;
    esac
    # Fallback: if thumbnail failed, symlink to source (wofi will try to render it)
    [[ -s "$out" ]] || ln -sf "$src" "$out"
  fi

  # Display uses thumbnail + basename; output of wofi remains the original line
  printf 'img:%s:text:%s\n' "$out" "$(basename "$src")"
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
  # tiny wait to ensure the socket is ready
  sleep 0.25
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
       --image-size "$THUMB_SIZE" \
       --columns "$COLUMNS" \
       --prompt "$WOFI_PROMPT" \
       --cache-file "$CACHE_FILE"
)"

# User canceled
[[ -n "${SEL// }" ]] || { echo "Canceled."; exit 0; }

# hyprpaper wants absolute paths; ensure we have one
SEL_ABS="$(readlink -f -- "$SEL")" || SEL_ABS="$SEL"

# Apply wallpaper:
# - Using 'reload' sets immediately (no preload)
# - ",PATH" applies to all monitors; otherwise we set monitor,PATH
if [[ "$TARGET_MONITOR" == "all" ]]; then
  hyprctl -q hyprpaper reload ",$SEL_ABS" || die "hyprpaper reload failed"
else
  hyprctl -q hyprpaper reload "$TARGET_MONITOR,$SEL_ABS" || die "hyprpaper reload failed for $TARGET_MONITOR"
fi

# Free memory from old preloads if any
hyprctl -q hyprpaper unload unused || true

# Persist last choice
echo "$SEL_ABS" > "$CACHE_ROOT/last"

notify-send -t 1500 "Wallpaper updated" "$(basename "$SEL_ABS")"
echo "Wallpaper set: $SEL_ABS"
