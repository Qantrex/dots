# ✨ My Dotfiles

<p align="center">
  <img src="https://img.shields.io/badge/Arch_Linux-grey?logo=arch-linux&logoColor=1793D1&style=for-the-badge">
  <img src="https://img.shields.io/badge/Hyprland-grey?logo=wayland&logoColor=4A90E2&style=for-the-badge">
  <img src="https://img.shields.io/badge/Stow-grey?logo=gnu&logoColor=A42E2B&style=for-the-badge">
</p>

Welcome to my **dotfiles** 👾
Managed with [GNU Stow](https://www.gnu.org/software/stow/) for clean symlinks and portability.

**Machine:** ASUS Vivobook Pro 14X OLED (M7400QC) · Ryzen 9 5900HX · 2880x1800 @ 90 Hz

---

## 📦 What's inside

| Package | What it configures |
| --- | --- |
| 🌌 `hypr` | Hyprland compositor, hyprlock, hyprpaper |
| 📊 `waybar` | Status bar |
| 🐟 `fish` | Shell, functions and prompt |
| 🖼 `foot` | Terminal emulator |
| ✍️ `micro` | Terminal editor |
| 🔔 `fnott` | Notification daemon config (mako is what actually runs) |
| 🔍 `wofi` | Application launcher |
| 🎨 `gtk` | GTK 3/4 theming |
| 🎛 `qt5ct` | Qt5 theming |
| ⚙️ `scripts` | Helper scripts |

---

## Clone the Repo

```bash
# Install prerequisites
sudo pacman -S --needed git stow

# Clone into home
git clone https://github.com/Qantrex/dots.git ~/dotfiles
cd ~/dotfiles
```

---

## Apply Configs with Stow

```bash
# Symlink all configs into ~/.config
stow -v micro fish fnott foot qt5ct waybar gtk wofi scripts hypr
```

Now `~/.config/...` points directly into your `~/dotfiles`.

Verify with:

```bash
~/dotfiles/verify-dotfiles.sh
```

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

```bash
# Compositor and its ecosystem
yay -S hyprland hyprlock hyprpaper hyprpolkitagent \
       xdg-desktop-portal-hyprland

# Shell, terminal, editor, launcher, bar
yay -S fish foot micro wofi wofimoji waybar qt5ct dolphin

# Desktop services the Hyprland autostart expects
yay -S mako swayidle swayosd batsignal \
       cliphist wl-clipboard grim slurp \
       playerctl brightnessctl wireplumber

# Power management (see below)
yay -S asusctl tlp

# Fonts and cursors -- the bar and lockscreen reference these by name
yay -S ttf-jetbrains-mono-nerd rose-pine-hyprcursor
```

---

## Finish Setup

```bash
chsh -s /usr/bin/fish
sudo systemctl enable --now tlp
sudo ~/.config/scripts/setup-power-profiles.sh
```

---

## 🌌 Hyprland config

Hyprland uses the **Lua** config format, which replaced hyprlang as the
supported format in Hyprland 0.55.

```
hypr/.config/hypr/
├── hyprland.lua          entry point, requires the modules below
├── lua/
│   ├── apps.lua          programs used elsewhere in the config
│   ├── monitors.lua
│   ├── env.lua
│   ├── look.lua          gaps, borders, blur, glow, shadows, animations
│   ├── input.lua         keyboard, touchpad, gestures
│   ├── keybinds.lua
│   ├── rules.lua         window + layer rules
│   ├── permissions.lua
│   └── autostart.lua     runs on the `hyprland.start` event
├── hyprlock.conf         separate program, still hyprlang
└── hyprpaper.conf        separate program, still hyprlang
```

Each `require` runs in its own scope, so an error in one module does not stop
the others from loading.

The previous hyprlang config is preserved in
`hypr/.config/hypr/_backup-hyprlang-<date>/`.

### Keybindings

`SUPER` is the modifier. `hyprctl binds` lists everything with descriptions.

| Key | Action |
| --- | --- |
| `T` / `E` / `A`,`R` | Terminal / file manager / launcher |
| `C` / `L` | Clipboard history / lock |
| `Q` / `V` / `F` | Close / float / fullscreen |
| `arrows` | Move focus (`+SHIFT` moves the window) |
| `1`–`0` | Workspace (`+SHIFT` moves the window there) |
| `S` | Scratchpad |
| `CTRL+S` | Screenshot region → file + clipboard |
| `F1` / `F2` / `F3` | Power profile: Quiet / Performance / Balanced |
| `SHIFT+R` | Reload config and restart the bar |

---

## 🔋 Power profiles

The laptop exposes an ACPI platform profile (`quiet` / `balanced` /
`performance`) that drives both the EC fan curve and, through `amd-pstate`, the
CPU energy-performance preference. This Vivobook does **not** support custom fan
curves or PPT tuning (`asusctl fan-curve` reports no `FanCurves` interface and
`asusctl armoury list` is empty), so the platform profile is the only fan lever.

Switch with `SUPER+F1`/`F2`, the waybar module, or:

```bash
~/.config/scripts/powerprofile.sh quiet|balanced|performance|toggle|cycle
```

No root needed — `asusctl` is authorised through polkit.

### One-time setup

```bash
sudo ~/.config/scripts/setup-power-profiles.sh
```

TLP's defaults otherwise fight the platform profile (it re-applies
`PLATFORM_PROFILE_ON_AC` on every AC/battery transition) and can pin the CPU to
its base clock. The script disables just those TLP parameters, keeps boost
enabled, and leaves TLP's USB/PCIe/disk/Wi-Fi power saving alone. It backs up
everything it edits; `--undo` reverts it and `--show` prints the current state
plus which config file wins for each setting.

Measured on this machine:

| Profile | peak 1-core | CPU fan under load |
| --- | --- | --- |
| Quiet | 4042 MHz | 3500 RPM |
| Performance | 4464 MHz | 7300 RPM |

Sustained all-core is thermally limited to ~3.3 GHz in both; the difference is
burst clock and cooling aggressiveness.

---

## ⚠️ Notes

- Machine-specific state (`fish_variables`, `micro/buffers`, `wofi/history`) is
  ignored via `.gitignore`. The patterns must be written as `*/.config/...` to
  match the stow layout — an unprefixed `.config/...` pattern anchors to the
  repo root and silently matches nothing.
- Edits go directly into `~/.config/...`, which *is* this repo via the stow
  symlinks — so just `git add`/`commit` here, no copying needed.

---

## 🧑‍💻 License

MIT — see [LICENSE](LICENSE).
