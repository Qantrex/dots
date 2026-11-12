#!/usr/bin/env bash
# Default apps and desktop settings, for the current user (no root).
#
#   ~/.config/scripts/set-default-apps.sh          apply
#   ~/.config/scripts/set-default-apps.sh --show   what opens what now
#
# Writes ~/.config/mimeapps.list through xdg-mime. Each type gets the first
# app of its list that is installed, so it is safe to run before the packages
# are there and again afterwards. Re-run after installing an app that grabs
# defaults for itself (PrismLauncher took .zip, Drawing took images,
# Amberol took folders).

set -uo pipefail

# mime types | candidates, best first
RULES=(
  "inode/directory|org.gnome.Nautilus.desktop yazi.desktop"
  "image/png image/jpeg image/gif image/webp image/bmp image/tiff image/svg+xml image/avif image/heic|imv.desktop org.gnome.Loupe.desktop"
  "application/pdf application/epub+zip|org.pwmt.zathura-pdf-mupdf.desktop org.pwmt.zathura.desktop firefox.desktop"
  "video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg|mpv.desktop"
  "audio/mpeg audio/flac audio/ogg audio/x-wav audio/wav audio/mp4 audio/x-m4a audio/opus audio/aac|io.bassi.Amberol.desktop mpv.desktop"
  "text/plain text/markdown text/x-log application/json application/toml application/x-yaml text/x-shellscript application/x-shellscript text/x-python text/css|micro-foot.desktop"
  "application/zip application/x-7z-compressed application/x-tar application/gzip application/x-xz application/zstd application/x-rar|org.gnome.Nautilus.desktop"
)

desktop_exists() {
  local f
  for f in ~/.local/share/applications/"$1" /usr/share/applications/"$1"; do
    [[ -f $f ]] && return 0
  done
  return 1
}

if [[ ${1:-} == --show ]]; then
  for rule in "${RULES[@]}"; do
    for m in ${rule%%|*}; do printf '%-34s %s\n' "$m" "$(xdg-mime query default "$m")"; done
  done
  exit 0
fi

for rule in "${RULES[@]}"; do
  types=${rule%%|*} app=
  for cand in ${rule#*|}; do
    desktop_exists "$cand" && { app=$cand; break; }
  done
  if [[ -z $app ]]; then
    printf '  ! none of (%s) installed; %s left as is\n' "${rule#*|}" "${types%% *}"
    continue
  fi
  for m in $types; do xdg-mime default "$app" "$m"; done
  printf '  %-36s -> %s\n' "${types%% *} (+$(( $(wc -w <<<"$types") - 1 )))" "$app"
done

# Accent for apps that read the GNOME setting instead of the CSS ("slate" is
# the only grey one), and the terminal font as the GTK monospace font.
if command -v gsettings >/dev/null; then
  gsettings set org.gnome.desktop.interface accent-color slate 2>/dev/null
  gsettings set org.gnome.desktop.interface monospace-font-name 'IosevkaTerm Nerd Font Mono 11'
  # Nautilus: list view, folders first, no recent/starred noise.
  if gsettings list-schemas | grep -qx org.gnome.nautilus.preferences; then
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
    gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true 2>/dev/null
    gsettings set org.gnome.nautilus.preferences show-delete-permanently true
  fi
  # localsearch (Nautilus' indexer) defaults to all of $HOME, which here means
  # ~/models, ~/vms and the mail store: hours of CPU on battery. Index the
  # folders worth searching; $HOME itself only one level deep.
  if gsettings list-schemas | grep -qx org.freedesktop.Tracker3.Miner.Files; then
    gsettings set org.freedesktop.Tracker3.Miner.Files index-recursive-directories \
      "['&DOCUMENTS', '&DOWNLOAD', '&PICTURES', '&MUSIC', '&VIDEOS', '\$HOME/Notes', '\$HOME/Projects']"
    gsettings set org.freedesktop.Tracker3.Miner.Files index-single-directories "['\$HOME', '&DESKTOP']"
  fi
  echo "  gsettings: accent slate, monospace Iosevka Term, search index limited"
fi
update-desktop-database ~/.local/share/applications 2>/dev/null || true
