#!/usr/bin/env bash
# Build "Papirus-Mono": Papirus-Dark with grey instead of blue folders.
#
# papirus-folders does the same by rewriting /usr/share/icons (needs root and
# is undone by every papirus update). This builds a small user theme in
# ~/.local/share/icons that only overrides the folder symlinks and inherits
# everything else from Papirus-Dark. Re-run after a papirus-icon-theme update.
set -euo pipefail

COLOR=${1:-grey}
SRC=/usr/share/icons/Papirus-Dark
DEST=$HOME/.local/share/icons/Papirus-Mono

rm -rf "$DEST"
mkdir -p "$DEST"
dirs=()

for placesdir in "$SRC"/*/places; do
  rel=${placesdir#"$SRC"/}          # e.g. 48x48/places
  real=$(realpath "$placesdir")
  made=0
  while IFS= read -r link; do
    target=$(readlink "$link")
    grey=${target//-blue/-$COLOR}
    [[ -e $real/$grey ]] || continue
    mkdir -p "$DEST/$rel"
    ln -s "$real/$grey" "$DEST/$rel/$(basename "$link")"
    made=1
  done < <(find "$real" -maxdepth 1 -type l -lname '*-blue*')
  ((made)) && dirs+=("$rel")
done

{
  echo "[Icon Theme]"
  echo "Name=Papirus-Mono"
  echo "Comment=Papirus-Dark with $COLOR folders"
  echo "Inherits=Papirus-Dark,breeze-dark,hicolor"
  echo "Directories=$(IFS=,; echo "${dirs[*]}")"
  for d in "${dirs[@]}"; do
    echo
    sed -n "/^\[${d//\//\\/}\]/,/^$/p" "$SRC/index.theme" | sed '/^$/d'
  done
} > "$DEST/index.theme"

gtk-update-icon-cache -q -f "$DEST" 2>/dev/null || true
echo "built $DEST (${#dirs[@]} dirs, $COLOR folders)"
