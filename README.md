# ✨ My Dotfiles

<p align="center">
  <img src="https://img.shields.io/badge/Arch_Linux-grey?logo=arch-linux&logoColor=1793D1&style=for-the-badge">
  <img src="https://img.shields.io/badge/Hyprland-grey?logo=wayland&logoColor=4A90E2&style=for-the-badge">
  <img src="https://img.shields.io/badge/Stow-grey?logo=gnu&logoColor=A42E2B&style=for-the-badge">
</p>

Welcome to my **dotfiles** 👾  
Managed with [GNU Stow](https://www.gnu.org/software/stow/) for clean symlinks and portability.  
Backups are automatically kept in `~/.config.bak-<timestamp>` whenever I re-link configs.

---

## Clone the Repo

```bash
# Install prerequisites
sudo pacman -S --needed git stow

# Clone into home
git clone https://github.com/<your-username>/dotfiles.git ~/dotfiles
cd ~/dotfiles
````

---

## Apply Configs with Stow

```bash
# Symlink all configs into ~/.config
stow -v micro fish fnott foot qt5ct waybar gtk wofi scripts hypr
```

Now `~/.config/...` points directly into your `~/dotfiles`.

---

## Install yay (AUR helper)

```bash
sudo pacman -S --needed base-devel git
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

Verify:

```bash
yay --version
```

---

## 🛠 Install Required Applications

With `yay` installed, grab all the apps my dotfiles configure:

```bash
yay -S \
  fish \
  micro \
  fnott \
  foot \
  qt5ct \
  waybar \
  wofi \
  hyprland \
  starship \
  pywal
```

---

## Finish Setup

  ```bash
  chsh -s /usr/bin/fish
  ```
---
