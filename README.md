# My Dotfiles

<p align="center">
  <img src="https://img.shields.io/badge/Arch_Linux-grey?logo=arch-linux&logoColor=1793D1&style=for-the-badge">
  <img src="https://img.shields.io/badge/Hyprland-grey?logo=wayland&logoColor=4A90E2&style=for-the-badge">
  <img src="https://img.shields.io/badge/Stow-grey?logo=gnu&logoColor=A42E2B&style=for-the-badge">
</p>

Welcome to my **dotfiles** 👾
Managed with [GNU Stow](https://www.gnu.org/software/stow/) for clean symlinks and portability.

**Machines:** `bauarch`, ASUS Vivobook Pro 14X OLED (M7400QC) · Ryzen 9 5900HX · 2880x1800 @ 90 Hz, and `bauarch-pc`, a desktop (Ryzen 5 3600, RTX 2060 Super, two AOC screens). Same repo on both; see [Per-machine differences](#per-machine-differences).

---

## What's inside

| Package | What it configures |
| --- | --- |
| `hypr` | Hyprland compositor, hyprlock, hyprpaper |
| `quickshell` | The desktop shell ([Quickshell](#shell-quickshell)): bar, popouts, notifications, OSD, launcher |
| `zsh` | `.zshrc` (oh-my-zsh), `.zsh_aliases`, functions (`gpumode`, `fixnet`, `hyprr`, …) |
| `starship` | Prompt |
| `fish` | Fish config (zsh is the login shell) |
| `foot` | Terminal emulator |
| `micro` | Terminal editor |
| `gtk` | GTK 3/4 theming |
| `qt5ct` / `qt6ct` | Qt5 / Qt6 theming (monochrome palette in `colors/`) |
| `kde` | `kdeglobals` colours for KDE apps (kid3, ghostwriter, …) |
| `tmux` | `~/.tmux.conf` |
| `vesktop` | Discord theme (`themes/` only) |
| `spicetify` | Spotify theme (Ziro + `monochrome` scheme) |
| `spotify-adblock` | Ad/tracking filter + `spotify.desktop` that loads it |
| `homerow` | Launcher entry and icon for the homerow typing test, a Rust TUI in its own foot window (`scripts/homerow.sh`). The binary is built from `~/Projects/homerow` with `npm run deploy` |
| `yazi` | yazi file manager: Enter steps into folders and opens files in their desktop app (Shift+Enter for every choice, e.g. edit in place), keys `gn` Nautilus here, `gT` terminal, `gv` vault, colours from the theme (`theme/templates/yazi.toml`) |
| `nautilus` | Nautilus right-click scripts: Open in yazi, Open terminal here |
| `desktop-entries` | `yazi.desktop` and `micro-foot.desktop`: open in a foot window, so folders / text files can default to them |
| `btop` / `cava` | btop `monochrome` theme + settings, cava grey gradient |
| `mpv` / `imv` / `zathura` | Video, image and PDF viewers, black with Iosevka text |
| `fastfetch` | White logo, grey keys |
| `scripts` | Helper scripts (`set-default-apps.sh` sets what opens folders, images, PDFs, audio, text) |
| `bin` | Commands on `$PATH` in `~/.local/bin`: `theme` switches the desktop theme (see [Themes](#themes)), `decide a b` throws a pixel-rendered 3D coin to pick one |
| `cmus` | `monochrome.theme` (terminal colour names, so it follows the theme) and an `rc` that loads it (cmus's autosave stays out of the repo) |
| `fontconfig` | `sans-serif` = Adwaita Sans, `monospace` = IosevkaTerm Nerd Font Mono |
| `glow` | Markdown viewer in the plain `notty` style |
| `nvim` | Minimal `init.lua`: the built-in `quiet` scheme on true black |

---

## Per-machine differences

One repo for both machines. Differences are picked by hostname (`/etc/hostname`), so nothing has to be switched by hand:

- **Hyprland:** `hypr/.config/hypr/lua/host.lua` gives `host.name`, `host.is_pc` and `host.file(dir, base, ext)`. Use `if host.is_pc then … else … end` for a setting that differs.
- **Other programs:** an optional `<base>-<hostname>.<ext>` next to the shared file. It includes the shared file and overrides only what differs. `host.file()` finds it.

| What | Laptop `bauarch` | Desktop `bauarch-pc` | Where |
| --- | --- | --- | --- |
| Monitors | internal panel, scale 2 | two AOC screens | `hypr/lua/monitors.lua` |
| Workspaces | one screen: 1–10, mail/music/chat on 8/9/10 | per screen 1–10 (side screen = Hyprland 11–20), chat/music/mail on the side screen's 1/2/3 | `hypr/lua/workspaces.lua` |
| Shell: Local AI tile/icon (`ai-webui.sh`) | yes | no (2026-11-04: the desktop is a headless AI node instead) | `quickshell/.../services/Scripts.qml` (`Host.isLaptop`) |
| Shell: battery, touchpad, power profile, brightness | yes | no (no battery, touchpad, asusctl or backlight) | `quickshell/.../services/` |
| Shell: GPU in the System popout (`nvidia-smi`) | no (it would wake the dGPU) | yes | `quickshell/.../services/Sys.qml` |
| Idle | dim, lock, screens off, suspend on battery | lock + quiet mode (`away --idle`), screens off, **never suspends** (AI node; only pc-guard may sleep it) | `scripts/idle.sh` |
| Power | asusctl profiles, SUPER+F1/F2/F3, low-battery warnings from the shell | none of those; SUPER+F1 or `away`: lock, screens off, `pc-quiet on` (CPU boost off, EPP power, GPU at 125 W) until unlock. One-time: `sudo ~/.config/scripts/setup-pc-quiet.sh` (the installer offers it). Fans are the BIOS's job: Q-Fan custom curve, flat ~20–30 % up to ~60 °C, then up to 100 % at ~80 °C, a few seconds of fan step up/down | `bin/away`, `scripts/pc-quiet`, `hypr/lua/keybinds.lua` |

---

## Install

Two installers, both safe to re-run. Pass `--dry-run` to see every command
first, or `--yes` to take the default answer to every question.

### From a bare Arch install

For the state `archinstall` leaves with the **Minimal** profile: base
system, kernel, bootloader, and a user with sudo. Log in on the TTY, get
online (`nmtui` or `iwctl`), then:

```bash
curl -fsSL https://raw.githubusercontent.com/Qantrex/dots/main/install.sh | bash
```

or, with the repo already cloned, `~/dotfiles/install.sh`. It:

1. updates the system and installs git, stow and yay (optionally adds the
   [chaotic-aur](https://aur.chaotic.cx) repo so AUR apps come prebuilt)
2. detects the GPU (AMD / Intel / NVIDIA, hybrid → `envycontrol`), laptop and
   ASUS hardware and installs drivers and tools for it
3. installs PipeWire, NetworkManager, bluetooth, Hyprland and everything the
   config starts, the shell tools, fonts, themes and apps
4. links the dotfiles (anything in the way goes to `~/.dotfiles-backup/<date>/`)
5. sets up oh-my-zsh and its plugins and makes zsh the login shell
6. enables the services and the greetd + tuigreet login screen
7. applies the Discord, Spotify and (optionally) Firefox themes, and offers
   Steam and Prism Launcher (`setup_gaming`, turns on multilib)
8. offers the one-time root scripts: firewall, ASUS power profiles,
   maintenance, boot tuning (off by default -- written for this laptop)

Then reboot.

### Onto an existing Hyprland setup

```bash
git clone https://github.com/Qantrex/dots.git ~/dotfiles
~/dotfiles/install-hyprland.sh
```

Same as above, except it leaves graphics drivers, the audio stack, the
network manager and your display manager alone (greetd only if there is
none). Your old `hypr`, `quickshell`, `foot`, ... configs are moved to
`~/.dotfiles-backup/<date>/`, and it warns about things that clash with
this setup (dunst/swaync/mako vs the shell's notifications, hypridle vs swayidle, swww vs hyprpaper).

### After the first login

Spotify has to run once before spicetify can theme it: start it, log in,
quit, and run the installer again. It only does what's still missing.

### Layout

```
install.sh            bare Arch → full desktop
install-hyprland.sh   existing Hyprland → these dotfiles
install/lib.sh        the steps both share
install/packages.sh   package lists
install/links.sh      every symlink into $HOME (also read by verify-dotfiles.sh)
theme/                the themes, their templates and the rendered one (see Themes)
```

To add a config: put it in a stow package, add its path to
`install/links.sh`, and if it needs packages, add them to
`install/packages.sh`.

Check the links at any time with `~/dotfiles/verify-dotfiles.sh`. After a
`git pull` that added, moved or removed configs, `~/dotfiles/install-hyprland.sh --links`
renders the theme and redoes the links, without packages or sudo.

---

## Hyprland config

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
└── hyprlock.conf         separate program, still hyprlang
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
| `T` / `A`,`R` | Terminal / launcher |
| `E` / `CTRL+E` | Files: yazi / Nautilus |
| `C` / `L` | Clipboard history / lock |
| `N` / `Escape` | Notifications / session menu (lock, suspend, log out, restart, shut down) |
| `SHIFT+E` / `SHIFT+W` | Emoji / wallpaper picker |
| `SHIFT+T` | Typing test (homerow) |
| `Q` / `V` / `F` | Close / float / fullscreen |
| `arrows` | Move focus (`+SHIFT` moves the window, `+ALT` throws it to the screen on that side) |
| `1`–`0` | Workspace on the screen you're on: each screen has its own 1–10 (`+SHIFT` moves the window there; `hypr/lua/workspaces.lua`) |
| `S` | Scratchpad |
| `ALT+F` | Maximize |
| `D` / `SHIFT+D` | Quick ask (Claude, Sonnet) / a fresh quick ask about the clipboard, text or image (`claude-ask.sh`) |
| `SHIFT+A` | Answer a waiting Claude session over the current workspace, in a floating window on its tmux window (`claude-peek.sh`); again to hide |
| `CTRL+S` | Screenshot region → file + clipboard |
| `SHIFT+F` | Screenshot region (flameshot) → Claude Code → answer as a faint bottom-right overlay (`~/.config/scripts/claude-screen/`) |
| `F1` / `F2` / `F3` | Power profile: Quiet / Performance / Balanced |
| `SHIFT+S` | Screenshot menu: region, window, monitor, all screens |
| `SHIFT+R` | Reload config and restart the shell |
| `SHIFT+V` | Unlock `~/Vault` and open it ([Vault](#vault)) |

`Fn+F6` (no `SUPER`) turns the touchpad on and off, as does the Touchpad tile in
the control centre (a crossed-out mouse in the bar means it is off). The state survives reloads and reboots
(`~/.config/scripts/touchpad.sh`).

---

## Shell (Quickshell)

One Quickshell process (`quickshell/.config/quickshell`, QML) is the whole
desktop shell. It replaced waybar, mako, swayosd, batsignal and the wofi menus
on 2026-11-12. The idea: **quiet by default, visible when something needs you**,
and every click opens something you can act in instead of another program.

**Bar** (32 px, three floating islands, blurred by Hyprland):

- **Left:** occupied workspaces as their apps' icons (greyed); the active one is
  a white pill, urgent ones pulse. A pin shows while the scratchpad has windows.
- **Centre:** the time, plus the next deadline when one is due within 2 days
  (`· ITP tomorrow`, gold on the day). The player shows while music plays (and
  5 minutes after a pause): click = media popout, middle = play/pause, scroll =
  previous/next.
- **Right, exceptions** (each only while it applies): mic / camera / screen share
  in use (love), homelab problems (love) or approvals waiting (gold), vault open,
  touchpad off, power profile above Quiet, local AI on, Claude sessions waiting for
  you (click: answer it here, middle-click: go to its terminal, right-click: dismiss;
  `claude-peek.sh` / `claude-jump.sh`, fed by the session hook in claude-config), Claude usage over 70 %, RAM over 85 % (gold),
  caffeine, Do Not Disturb, unread notifications, no or limited network.
- **Right, status:** network, Bluetooth (only with a device connected), volume,
  battery (percentage only on battery; gold under 30 %, love under 15 %). One
  click target: the control centre. Scroll = volume, middle = mute, right =
  pavucontrol. The tray hides behind the chevron.

**Popouts:** *control centre* (volume, mic and per-app sliders, output/input
device, brightness, Wi-Fi list with password entry, Bluetooth devices with
battery and pairing, power profile, touchpad, vault, Do Not Disturb, caffeine,
local AI, battery time, lock/suspend/restart/shut down); *day* (click the clock:
date, weather, month calendar with deadline dots, today's lessons, deadlines,
to-dos you can tick off); *media*; *system* (CPU, RAM, temperature, fan, GPU on
the PC); *notifications*; *homelab*; *tray*.

**The day popout's data** comes from the homelab agent's Companion API
(`GET /api/v1/state`, the same as the iOS app: WebUntis, Moodle, the notes'
`due:` dates, Home Assistant to-dos), reached over the tailnet. Its URL is not
in this repo: put it in `~/.config/homelab/api-url` (one line). Without it the
popout shows the calendar only.

**Launcher** (`SUPER+A`/`R`): apps (ranked by use), clipboard (`SUPER+C`), emoji
(`SUPER+SHIFT+E`), screenshot (`SUPER+SHIFT+S`), wallpaper (`SUPER+SHIFT+W`) and
session (`SUPER+Escape`). Tab switches mode, Enter runs, Shift+Del removes a
clipboard entry. The emoji list is generated: `python3 -I tools/gen-emoji.py`.

**Notifications:** popups top right, 5 s (critical ones stay, with a love
border); hover pauses them. Everything stays in the history (`SUPER+N`) until
dismissed. Do Not Disturb keeps critical ones only.

**OSD:** volume (from anywhere), mic mute and brightness, bottom centre.

**IPC** (`qs ipc show` lists all): the scripts call `qs ipc call bar refresh
<vault|touchpad|powerprofile|ai>` after a change; keybinds use `launcher toggle
<mode>`, `bar popout <name>`, `osd brightness`; also `notifs dnd`, `caffeine
toggle`, `homelab refresh`.

Every bar icon has a tooltip (what it is, what the clicks do).

`scripts/shell.sh` starts it (autostart) and restarts it if it crashes, so a
crash never leaves the session without a bar and notifications; `shell.sh
restart` (SUPER+SHIFT+R, `hyprr`) restarts it on purpose. Quickshell also
reloads itself when a file changes. The config is `~/.config/quickshell`, the
log `qs log`, the look and colours `services/Theme.qml`.

The Hyprland config is Lua, so dispatches from the shell and scripts are Lua as
well: `hyprctl dispatch 'hl.dsp.focus({ workspace = "e+1" })'`, not
`hyprctl dispatch workspace e+1` (that fails).

---

## Power profiles

The laptop exposes an ACPI platform profile (`quiet` / `balanced` /
`performance`) that drives both the EC fan curve and, through `amd-pstate`, the
CPU energy-performance preference. This Vivobook does **not** support custom fan
curves or PPT tuning (`asusctl fan-curve` reports no `FanCurves` interface and
`asusctl armoury list` is empty), so the platform profile is the only fan lever.

Switch with `SUPER+F1`/`F2`, the Power tile in the control centre, or:

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

## GPU mode

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

## Boot time

```bash
sudo ~/.config/scripts/optimize-boot.sh   # --dry-run / --show also available
```

One-time pass that fixes a `quit` → `quiet` typo in the kernel cmdline, wires
up `amd-ucode`, adds a fallback boot entry (there was none, and
`loader.conf` has `timeout 0` — hold Space at boot for the menu), trims the
initramfs for the current GPU mode, and socket-activates docker and libvirtd.
It used to drop the plymouth splash (~500 ms); there is no splash any more
(see below).

> Containers with `restart: always` and VMs marked autostart will no longer
> come up by themselves at boot — they start when something first touches
> docker/libvirt.

### Boot and login style

```bash
sudo ~/.config/scripts/setup-boot-style.sh   # --dry-run / --boot / --greeter / --palette / --undo
```

- **Boot:** no splash. With the quiet flags the plain console stays black for a
  second or two, then the login. (A plymouth theme that animated a fake boot log
  was removed on 2026-11-15; `--boot` takes out its hook, `splash` and the theme.)
- **Console:** the same grey 16-colour palette as foot on the kernel command line
  (`vt.default_red/grn/blu`, slot 0 stays black as the background) and Terminus
  32 px (`ter-v32b`), so TTYs match the desktop and are readable on the
  2880x1800 panel. `--palette` updates only the colours, without rebuilding the
  initramfs.
- **Login:** greetd runs `/etc/greetd/tuigreet.sh` (`install/greeter/tuigreet.sh`,
  shared by both machines): plain tuigreet on black, grey theme, remembered user,
  date and time. No animated background.

Needs `terminus-font greetd-tuigreet`.

---

## Maintenance

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

## Themes

The whole desktop switches between themes with one command:

```bash
theme                 # the current theme and the ones there are
theme set root        # render a theme and switch everything to it
theme apply           # render the current theme again (after editing a palette or template)
theme render NAME DIR # only render into DIR, change nothing (to diff or check a theme)
```

There is one theme so far, **root**: true-black monochrome (`#000000`, white and
greys) for the OLED panel. Selections, buttons and active states are greys or
white. Rosé Pine Moon colour appears only where it helps reading: love / gold
for errors and warnings, and rose / iris for Discord mentions and links and for
syntax highlighting. It is never used as a full-app theme.

### How it works

```
theme/
├── themes/<name>/theme.toml    one file per theme: palette, terminal colours, fonts, look, assets
├── themes/<name>/templates/    optional: a theme's own version of a template (e.g. hyprlock)
├── templates/                  one template per app, with {{ ... }} where values go
├── generators/gtk.py           builds the GTK 3/4 theme from the installed Adwaita
├── generators/yazi_template.py writes templates/yazi.toml from yazi's preset (after a yazi update)
├── build/<name>-<time>/        the rendered theme (git-ignored)
└── current -> build/…          what the apps read (git-ignored)
```

`theme set` (`bin/.local/bin/theme`) renders every template into a fresh
`build/` folder, then swaps the `current` link in one step, so apps never see a
half-written theme. Tracked files never change when you switch, and nothing runs
between switches. The configs in the repo reach `theme/current` in one of two
ways:

- **An include line** where the app can include a file: foot, tmux, zathura,
  mpv, nvim, Hyprland (`lua/theme.lua`) and the shell (`Theme.qml` reads
  `theme.json`). The link sits next to the config, named `theme.*`.
- **The config file itself is a symlink** into `theme/current` where the file is
  mostly colours or the app has no include: btop, cava, imv, micro, yazi, Vesktop,
  spicetify, zsh colours, Qt (qt5ct/qt6ct and their colour scheme), kdeglobals,
  GTK settings and `gtk.css`, fontconfig, hyprlock, and the GTK theme
  (`~/.local/share/themes/Current`). To change such a config, edit its template
  in `theme/templates/` and run `theme apply`; an edit to the live file is lost
  on the next switch.

The links are relative, so the repo has to live at `~/dotfiles` (as the install
assumes anyway). The installer renders the theme before it links anything.

After a switch, Hyprland, the shell, GTK (gsettings), the cursor, tmux and the
wallpaper change at once. Spotify (spicetify is refreshed), Discord, open
terminals, btop, yazi, nvim and zathura show the new theme the next time they
start. Firefox keeps its own theme (`assets.firefox` names the right one).

### Templates

A template is the app's config with `{{ expression }}` where a value goes.
Everything in the theme's `[colors]` is a name (`bg`, `fg`, `text`, `accent`,
`on_accent`, `love`, `gold`, `iris`, …), plus `term.red` and the other terminal
colours, `font.mono`, `look.radius`, `asset.wallpaper` and the theme's `theme`
name and `dark` flag. Colours print as `#rrggbb` and have formats for other
syntaxes: `.hex` (`rrggbb`), `.hexa`, `.argb` (Qt), `.dec` (`r, g, b`), `.csv`,
plus `.a(0x2e)` / `.alpha(0.18)` for transparency.

Greys are written as `tone(0x55)`: that many 255ths of the way from `bg` to
`fg`. In root that is exactly `#555555`, so root renders byte for byte like the
old hand-written configs; in a theme with another `bg` and `fg` the same step
lands between its own two ends. Places that mark "this one" (selection, the
active tab or tile, today in the calendar, slider levels) use `accent` and
`on_accent` instead, which in root are white and black.

### A new theme

1. Copy `theme/themes/root/theme.toml` to `theme/themes/<name>/theme.toml` and
   change the palette, fonts, look and assets.
2. `theme render <name> /tmp/x` and look through the files, then `theme set <name>`.
3. Where the tone steps don't suit the new palette, copy that template to
   `theme/themes/<name>/templates/` and change it there. The lock screen's layout
   belongs to root's wallpaper (the password sits between the fingers), so a theme
   with another wallpaper wants its own `hyprlock.conf`.

`assets.gtk_theme` can name an installed GTK theme instead of the generated one,
and `assets.icon_theme` any installed icon theme (`build-papirus-mono.sh <colour>`
makes Papirus variants).

### Not themed

Apps that only use the terminal's colour names follow the theme through foot's
palette: cmus, starship, fastfetch, glow (`notty`), `ls` / eza and bat. These stay
the same in every theme: the boot splash, console and login screen
(`setup-boot-style.sh`, see [Boot time](#boot-time)), the screenshot selection
(`screenshot.sh`), htop (its Monochromatic scheme), fish (not the login shell),
and Obsidian and Code-OSS, which keep their themes in their own settings.

### root, app by app

| App | Template (in `theme/templates/`) and notes |
| --- | --- |
| GTK3 / GTK4 apps | `generators/gtk.py`: Adwaita-dark recoloured to the palette (a GTK update needs `theme apply`) |
| libadwaita apps | `gtk4.css`, and `gtk-settings.ini` for GTK's own settings |
| Icons | `Papirus-Mono` (Papirus-Dark with grey folders), built into `~/.local/share/icons` by `~/.config/scripts/build-papirus-mono.sh` |
| Bar, popouts, notifications, launcher | `quickshell.json`, read by `quickshell/.../services/Theme.qml` |
| Discord | `vesktop.theme.css` (derived from rose-pine/discord, palette swapped) |
| Spotify | Ziro theme, `[theme]` scheme in `spicetify-color.ini` |
| Qt / KDE | `qt-colors.conf`, `qt5ct.conf`, `qt6ct.conf`, `kdeglobals` |
| micro | `micro.micro` |
| Terminal | `foot.ini`: Iosevka Term 13 (`ttf-iosevkaterm-nerd`), grey ANSI palette (red and yellow stay love and gold); tmux bar in `tmux.conf` |
| Shell colours | `zsh-colors.zsh`: ls, eza, completion, syntax highlighting, fzf, bat, less |
| Fonts | `fonts.conf` and the qt5ct / qt6ct font lines: Adwaita Sans and IosevkaTerm |
| Cursor | Adwaita (XCursor), from `assets.cursor_theme` for Hyprland's `env.lua` and gsettings; `~/.icons/default` (written by the installer) also names Adwaita |
| nvim | `nvim.lua`: the built-in `quiet` scheme in the palette |
| Window borders, gaps, rounding | `hypr.lua`, read by `hypr/.../lua/theme.lua` |
| Lock screen | `hyprlock.conf`: the dimmed ASCII "Creation of Adam" wallpaper, the clock above, and the password typed into the gap between the two fingers |
| Files | yazi: `yazi.toml` (generated by `generators/yazi_template.py`); Nautilus: libadwaita, so `gtk4.css` |
| btop / cava | `btop.theme`, `cava.conf` (the whole cava config) |
| Viewers | `mpv.conf`, `imv.conf` (the whole imv config), `zathurarc` (PDFs recoloured white-on-black, Ctrl+R for paper) |
| Wallpaper | `~/Pictures/Wallpapers/ascii-creation-of-adam.png` (from JaxonWright/omarchy-midnight-theme); SUPER+SHIFT+W picks another, kept across logins until the next `theme set` |

### Spotify: spicetify + adblock

Spotify is started through `~/.local/share/applications/spotify.desktop` and
`apps.lua` with `LD_PRELOAD=/usr/lib/spotify-adblock.so`. `spicetify apply`
restarts Spotify **without** that preload, so always apply with `-n` and
start Spotify yourself:

```bash
spicetify apply -n            # after changing the theme/scheme
spicetify restore backup apply -n   # after a Spotify update
```

The adblock config in `spotify-adblock/` overrides `/etc/spotify-adblock/`:
Spotify now talks to regional hosts (`gew4-spclient.spotify.com`,
`gew4-dealer.g2.spotify.com`) that the stock lists don't match, so ads got
through and the realtime "dealer" connection was blocked. Check it with:

```bash
env LD_PRELOAD=/usr/lib/spotify-adblock.so spotify | grep '^\[-\]'
```

---

## Vault

`~/Vault` is a password-protected folder (gocryptfs). Its files are stored
encrypted in `~/.vault`; `~/Vault` only exists while it is unlocked, and it
stays unlocked until `vault lock` or shutdown.

The password is a random 256-bit key that lives only in the Bitwarden entry
**Vault (gocryptfs)**, next to the gocryptfs master key for recovery. The entry
has *master password re-prompt* on, so `rbw` asks for the master password on
every unlock, even while it is otherwise unlocked. The key goes straight from
`rbw` into gocryptfs and is never shown or copied.

Unlock with `SUPER+SHIFT+V` (opens the default file manager), the Vault tile in the control
centre, or `vault`. While it is open an open-lock icon sits in the bar: a click
opens `~/Vault`, a right-click (or `vault lock`, or the tile) closes it.

One-time setup (needs `gocryptfs` and a logged-in `rbw`):

```bash
vault init
```

Then open the entry in the Bitwarden app, tick *Master password re-prompt*,
save, and run `rbw sync`.

`~/.vault` is not part of these dotfiles. Back it up like any other data; it is
encrypted, so any backup location is fine. After a reinstall, restore it and the
key is still in Bitwarden.

---

## Notes

- Machine-specific state (`fish_variables`, `micro/buffers`) is
  ignored via `.gitignore`. The patterns must be written as `*/.config/...` to
  match the stow layout — an unprefixed `.config/...` pattern anchors to the
  repo root and silently matches nothing.
- Edits go directly into `~/.config/...`, which *is* this repo via the stow
  symlinks — so just `git add`/`commit` here, no copying needed.

---

## License

MIT — see [LICENSE](LICENSE).
