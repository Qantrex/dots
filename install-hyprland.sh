#!/usr/bin/env bash
# Put these dotfiles on a machine that already runs a small Hyprland setup.
#
#   ~/dotfiles/install-hyprland.sh [--yes] [--dry-run]
#
# Compared to install.sh this assumes graphics, audio, network and login
# already work, and leaves them alone: no GPU drivers, no PipeWire (it would
# replace PulseAudio), no NetworkManager switch, and your display manager stays
# unless there is none. Existing configs that these dotfiles replace (hypr,
# waybar, wofi, foot, ...) are moved to ~/.dotfiles-backup/<date>/ first.
#
# Safe to re-run; run it again after first starting Spotify to theme it.

set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=install/lib.sh
source "$here/install/lib.sh"

parse_args "$@"
preflight
command -v Hyprland >/dev/null || die "Hyprland isn't installed -- use install.sh for a bare system."

system_upgrade
install_bootstrap
setup_chaotic_aur
bootstrap_yay

detect_hardware --no-gpu
install_pkgs "laptop"           "${HW_PKGS[@]}"
install_pkgs "Hyprland desktop" "${PKG_DESKTOP[@]}"
install_pkgs "shell"            "${PKG_SHELL[@]}"
install_pkgs "fonts"            "${PKG_FONTS[@]}"
install_pkgs "themes"           "${PKG_THEME[@]}"
install_pkgs "apps"             "${PKG_APPS[@]}"
install_pkgs "system"           "${PKG_SYSTEM[@]}"
check_hyprland_version

step "Checking for things that clash with this setup"
# These would fight mako / hyprpaper / swayidle, which the config autostarts.
# dunst and swaync also claim notifications through D-Bus activation, so
# being installed is enough to clash.
for p in dunst swaync hypridle swww; do
  pacman -Qq "$p" &>/dev/null && warn "$p is installed; this setup uses $(
    case $p in dunst|swaync) echo mako ;; hypridle) echo swayidle ;; swww) echo hyprpaper ;; esac
  ) instead -- consider removing it"
done
command -v nmcli >/dev/null || info "NetworkManager isn't installed; waybar's network click (nmtui) won't work"
pacman -Qq pipewire-pulse &>/dev/null || info "No PipeWire; waybar's volume module works with PulseAudio too"

link_dotfiles
setup_shell

step "Login"
if systemctl is-enabled --quiet display-manager.service 2>/dev/null; then
  info "keeping $(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service); pick the Hyprland session there"
elif ask "No display manager is enabled. Use greetd + tuigreet as the login screen?" y; then
  install_pkgs "login screen" "${PKG_LOGIN[@]}"
  setup_greetd
fi
if ((HW_LAPTOP)); then
  # TLP and power-profiles-daemon both drive the same knobs; don't run both.
  if systemctl is-enabled --quiet power-profiles-daemon.service 2>/dev/null; then
    warn "power-profiles-daemon is enabled -- not enabling TLP alongside it"
  else
    enable_services tlp.service
  fi
fi
run xdg-user-dirs-update

setup_vesktop
setup_spicetify
setup_firefox_theme
run_root_scripts
check_home_paths
verify
summary "Log out and back in (or reboot) to load the new Hyprland config."
