#!/usr/bin/env bash
# Full desktop from a bare Arch install -- the state `archinstall` leaves with
# the "Minimal" profile: base system, kernel, bootloader, and a user in the
# wheel group with sudo. No GUI, maybe not even git.
#
#   curl -fsSL https://raw.githubusercontent.com/Qantrex/dots/main/install.sh | bash
#   ~/dotfiles/install.sh [--yes] [--dry-run]
#
# Already running Hyprland? Use install-hyprland.sh instead -- it leaves your
# audio, network and login manager alone.
#
# Safe to re-run; run it again after first starting Spotify to theme it.

set -uo pipefail

# Piped from curl (or copied somewhere on its own): fetch the repo, then run
# the copy inside it.
here=$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)
if [[ ! -f $here/install/lib.sh ]]; then
  sudo pacman -S --needed --noconfirm git || exit 1
  [[ -d $HOME/dotfiles/.git ]] || git clone https://github.com/Qantrex/dots.git "$HOME/dotfiles" || exit 1
  exec bash "$HOME/dotfiles/install.sh" "$@" </dev/tty
fi
# shellcheck source=install/lib.sh
source "$here/install/lib.sh"

parse_args "$@"
preflight
system_upgrade
install_bootstrap
setup_chaotic_aur
bootstrap_yay

detect_hardware
install_pkgs "graphics / hardware" "${HW_PKGS[@]}"
install_pkgs "audio"               "${PKG_AUDIO[@]}"
install_pkgs "network, bluetooth"  "${PKG_NETWORK[@]}"
install_pkgs "login screen"        "${PKG_LOGIN[@]}"
install_pkgs "Hyprland desktop"    "${PKG_DESKTOP[@]}"
install_pkgs "shell"               "${PKG_SHELL[@]}"
install_pkgs "fonts"               "${PKG_FONTS[@]}"
install_pkgs "themes"              "${PKG_THEME[@]}"
install_pkgs "apps"                "${PKG_APPS[@]}"
install_pkgs "system"              "${PKG_SYSTEM[@]}"
check_hyprland_version

link_dotfiles
setup_shell
setup_micro

step "Services"
# archinstall may have set up systemd-networkd or iwd instead of NetworkManager.
# Switch at the next boot rather than now, so the connection this script is
# using stays up.
others=()
for unit in systemd-networkd.service iwd.service; do
  systemctl is-enabled --quiet "$unit" 2>/dev/null && others+=("$unit")
done
if ((${#others[@]})); then
  info "switching ${others[*]} -> NetworkManager at the next boot"
  run sudo systemctl disable "${others[@]}"
  enable_services NetworkManager.service
else
  enable_services --now NetworkManager.service
fi
enable_services bluetooth.service
((HW_LAPTOP)) && enable_services tlp.service
# PipeWire runs per user; --global enables it for every user's session.
run sudo systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service \
  || FAILED+=("pipewire user units")
run xdg-user-dirs-update

setup_greetd
setup_icon_theme
setup_vesktop
setup_spicetify
setup_firefox_theme
run_root_scripts
check_home_paths
verify
summary "Reboot to get the login screen: sudo reboot"
