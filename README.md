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
| 🐚 `zsh` | zsh functions (`gpumode`, `fixnet`, `hyprr`, …) |

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
stow -v micro fish fnott foot qt5ct waybar gtk wofi scripts hypr zsh
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

The previous hyprlang config lives in git history, at the commit before it
was removed:

```bash
git show 8122bbf:hypr/.config/hypr/_backup-hyprlang-2026-09-23/hyprland.conf
```

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

## 🎮 GPU mode

The dedicated RTX 3050 is switched with [envycontrol](https://github.com/bayasdev/envycontrol)
via the `gpumode` zsh function:

```bash
gpumode off     # integrated AMD only (battery)
gpumode on      # dedicated NVIDIA
gpumode status  # mode, initramfs size, MODULES line
```

`gpumode` also rewrites `MODULES=` in `/etc/mkinitcpio.conf` to match the mode,
*before* handing over to envycontrol (which rebuilds the initramfs itself).
In nvidia mode the modules are needed for early KMS; in integrated mode they
are blacklisted and never load, but mkinitcpio would still pack them plus
~109 MB of GSP firmware — a 142 MB versus 48 MB initramfs.

---

## ⏱ Boot time

```bash
sudo ~/.config/scripts/optimize-boot.sh   # --dry-run / --show also available
```

One-time pass that fixes a `quit` → `quiet` typo in the kernel cmdline, wires
up `amd-ucode`, adds a fallback boot entry (there was none, and
`loader.conf` has `timeout 0` — hold Space at boot for the menu), trims the
initramfs for the current GPU mode, drops the plymouth boot splash (~500 ms
across its four units), and socket-activates docker and libvirtd.

> Containers with `restart: always` and VMs marked autostart will no longer
> come up by themselves at boot — they start when something first touches
> docker/libvirt.

---

## 🧹 Maintenance

```bash
sudo ~/.config/scripts/maintain.sh   # --dry-run / --show also available
```

Re-runnable; every step checks before acting. It prunes the pacman cache
(which pacman never trims on its own — this machine reached **108 GB** across
21,420 files, including 50 versions each of `ollama-cuda`, `ollama` and
`linux`) and enables `paccache.timer` so it stays pruned. It also enables
`fstrim.timer`, masks the `systemd-sslh-generator` that SIGABRTs on every
boot, silences the `nvidia-utils` modules-load entry that logs
`could not find module by name='off'` in integrated GPU mode, and tightens
`/boot` permissions.

> `/boot` is vfat, so `chmod` is a no-op there — permissions come from the
> `fmask`/`dmask` mount options. The script edits fstab, backs it up, and
> restores it if the remount fails.

Orphaned packages are **reported, never removed**: "orphan" only means nothing
depends on it, and toolchains you invoke directly (`dotnet-sdk`, `clang`,
`doxygen`, `ant`) all qualify.

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
