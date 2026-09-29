# shellcheck shell=bash disable=SC2034
# Every symlink this repo puts into $HOME, as "path relative to ~|stow package".
# Sourced by install/lib.sh and verify-dotfiles.sh -- add new configs here.
#
# Each path is the exact point where the symlink lives. Usually that is a whole
# directory under ~/.config, but for apps whose config dir also holds session
# data or caches (vesktop, spicetify) only the themed part is linked. The
# installer creates each path's parent directory first, so stow links at exactly
# this level instead of folding a whole ~/.config/vesktop or ~/.local into the
# repo.

LINKS=(
  ".config/hypr|hypr"
  ".config/waybar|waybar"
  ".config/wofi|wofi"
  ".config/foot|foot"
  ".config/micro|micro"
  ".config/fish|fish"
  ".config/fnott|fnott"
  ".config/gtk-3.0|gtk"
  ".config/gtk-4.0|gtk"
  ".config/qt5ct|qt5ct"
  ".config/qt6ct|qt6ct"
  ".config/kdeglobals|kde"
  ".config/swayosd|swayosd"
  ".config/scripts|scripts"
  ".config/zsh|zsh"
  ".zshrc|zsh"
  ".zsh_aliases|zsh"
  ".config/starship.toml|starship"
  ".tmux.conf|tmux"
  ".config/vesktop/themes|vesktop"
  ".config/spicetify/Themes|spicetify"
  ".config/spotify-adblock|spotify-adblock"
  ".local/share/applications/spotify.desktop|spotify-adblock"
)
