#!/usr/bin/env bash
# Boot and login in the desktop's style: black, greys, Iosevka Term.
#
#   sudo ~/.config/scripts/setup-boot-style.sh             everything below
#   sudo ~/.config/scripts/setup-boot-style.sh --boot      only 1-4
#   sudo ~/.config/scripts/setup-boot-style.sh --greeter   only 5
#   sudo ~/.config/scripts/setup-boot-style.sh --palette   only the console colours (3), no initramfs rebuild
#   sudo ~/.config/scripts/setup-boot-style.sh --dry-run   show, change nothing
#   sudo ~/.config/scripts/setup-boot-style.sh --undo      revert 1-4
#
# Needs: plymouth, ttf-iosevkaterm-nerd, terminus-font, greetd-tuigreet.
# Safe to re-run; every file it edits is copied to *.bak-<date> first.
#
# 1. Plymouth theme "terminal" (install/plymouth/terminal): systemd's units
#    scroll by as "[  ok  ] started NetworkManager.service" lines, real ones.
#    DeviceScale=1 so the script plugin draws text at native resolution.
#    Costs ~0.5 s of boot (optimize-boot.sh had removed plymouth for that).
# 2. "plymouth" in the mkinitcpio HOOKS, "splash" on the boot entries (not on
#    the fallback entry, which keeps the raw log for when something breaks).
# 3. Console palette on the kernel command line (vt.default_red/grn/blu): the
#    16 colours become black, greys, white, and Rose Pine love/gold/iris for
#    red/yellow/magenta. Every TTY uses it, tuigreet included.
# 4. Console font Terminus 32 px bold (ter-v32b), readable on the 2880x1800
#    panel instead of 8x16 dots. 180x56 characters there.
# 5. greetd runs /etc/greetd/tuigreet.sh (install/greeter/tuigreet.sh) as the
#    greeter user. On a host with install/greeter/<host>.lua it runs inside
#    that small Hyprland instead, like before.
#
# Never `systemctl restart greetd` from a desktop session: it ends the
# session. The new greeter shows at the next boot or logout.

set -euo pipefail

readonly HERE="$(dirname "$(readlink -f "$0")")"
readonly DOTFILES="$(cd "$HERE/../../.." && pwd)"
readonly THEME_SRC="$DOTFILES/install/plymouth/terminal"
readonly THEME_DST=/usr/share/plymouth/themes/terminal
readonly PLYCONF=/etc/plymouth/plymouthd.conf
readonly MKCONF=/etc/mkinitcpio.conf
readonly ENTRIES=/boot/loader/entries
readonly VCONSOLE=/etc/vconsole.conf
readonly CONSOLE_FONT=ter-v32b
readonly GREETER_SRC="$DOTFILES/install/greeter"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"

#                0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
#              blk red grn yel blu mag cyn wht  -- bright --
# Same greys as foot.ini (2026-11-15: every text colour readable at 4.9:1 or better), except
# slot 0, which is the console background here and stays pure black.
readonly VT_R=(0 235 192 246 138 196 163 208 122 255 224 255 168 238 200 255)
readonly VT_G=(0 111 192 193 138 167 163 208 122 152 224 235 168 208 200 255)
readonly VT_B=(0 146 192 119 138 231 163 208 122 186 224 158 168 255 200 255)

DRY=0 DO_BOOT=1 DO_GREETER=1 UNDO=0 PALETTE_ONLY=0
for arg in "$@"; do
    case $arg in
        --dry-run) DRY=1 ;;
        --boot)    DO_GREETER=0 ;;
        --greeter) DO_BOOT=0 ;;
        --palette) PALETTE_ONLY=1 DO_BOOT=0 DO_GREETER=0 ;;
        --undo)    UNDO=1 DO_GREETER=0 ;;
        -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
warn() { printf '   ! %s\n' "$*"; }
# act DESCRIPTION CMD...: run it, or with --dry-run only say what it would do.
act() {
    local what=$1; shift
    if (( DRY )); then say "   [dry-run] $what"; else "$@"; say "   $what"; fi
}
backup() { [[ -f $1 ]] && { (( DRY )) || cp -a "$1" "$1.bak-$STAMP"; }; return 0; }
join() { local IFS=,; echo "$*"; }

[[ $EUID -eq 0 ]] || { echo "setup-boot-style: run with sudo" >&2; exit 1; }

palette_opts="vt.default_red=$(join "${VT_R[@]}") vt.default_grn=$(join "${VT_G[@]}") vt.default_blu=$(join "${VT_B[@]}")"

# Rewrite the options line of a boot entry: drop our parameters, then add the
# wanted ones back (so re-running never duplicates them).
set_entry_options() {
    local entry=$1 add=$2 opts
    opts="$(grep -m1 -E '^options ' "$entry" | sed -E 's/^options +//')"
    opts="$(sed -E 's/(^| )(splash|vt\.default_(red|grn|blu)=[^ ]*)//g; s/  +/ /g; s/^ //; s/ $//' <<<"$opts")"
    [[ -n $add ]] && opts="$opts $add"
    if [[ "$(grep -m1 -E '^options ' "$entry" | sed -E 's/^options +//')" == "$opts" ]]; then
        say "   $(basename "$entry"): already set"
        return
    fi
    backup "$entry"
    act "$(basename "$entry"): options $opts" \
        sed -i -E "0,/^options .*/s||options $(sed 's/[&|]/\\&/g' <<<"$opts")|" "$entry"
}

# splash (not on fallback entries) and the console palette on every boot entry.
apply_entries() {
    for e in "$ENTRIES"/*.conf; do
        [[ -f $e ]] || continue
        if grep -qiE 'fallback' <<<"$(basename "$e") $(grep -m1 '^title' "$e")"; then
            set_entry_options "$e" "$palette_opts"
        else
            set_entry_options "$e" "splash $palette_opts"
        fi
    done
}

hooks_line() { grep -E '^HOOKS=' "$MKCONF"; }

rebuild_initramfs() {
    step "initramfs"
    act "rebuilt (mkinitcpio -P)" mkinitcpio -P
}

# ------------------------------------------------------------------- undo
if (( UNDO )); then
    step "Undo boot style"
    for e in "$ENTRIES"/*.conf; do set_entry_options "$e" ""; done
    if hooks_line | grep -qw plymouth; then
        backup "$MKCONF"
        act "removed the plymouth hook" sed -i -E '/^HOOKS=/{s/ plymouth\b//}' "$MKCONF"
    fi
    if grep -q "^FONT=$CONSOLE_FONT" "$VCONSOLE" 2>/dev/null; then
        backup "$VCONSOLE"
        act "removed FONT=$CONSOLE_FONT from $VCONSOLE" sed -i "/^FONT=$CONSOLE_FONT/d" "$VCONSOLE"
    fi
    rebuild_initramfs
    say ""; say "Done. The theme files in $THEME_DST and $PLYCONF are left in place."
    exit 0
fi

# ----------------------------------------------------------------- 1. theme
if (( PALETTE_ONLY )); then
    step "Boot entries (console palette only)"
    compgen -G "$ENTRIES/*.conf" >/dev/null || { warn "no systemd-boot entries in $ENTRIES"; exit 1; }
    apply_entries
    say ""
    say "Done. The new console colours show from the next boot."
    exit 0
fi

if (( DO_BOOT )); then
    step "Plymouth theme"
    command -v plymouth-set-default-theme >/dev/null || { echo "plymouth is not installed: pacman -S plymouth" >&2; exit 1; }
    fc-list 'IosevkaTerm Nerd Font Mono' family | grep -q . \
        || warn "Iosevka Term not installed (pacman -S ttf-iosevkaterm-nerd); the splash falls back to another monospace font"
    host="$(cat /etc/hostname 2>/dev/null || echo arch)"
    if (( DRY )); then
        say "   [dry-run] install $THEME_SRC -> $THEME_DST (host: $host)"
    else
        install -d -m 755 "$THEME_DST"
        install -m 644 "$THEME_SRC/terminal.plymouth" "$THEME_DST/terminal.plymouth"
        sed "s/@HOST@/$host/g" "$THEME_SRC/terminal.script" > "$THEME_DST/terminal.script"
        chmod 644 "$THEME_DST/terminal.script"
        say "   installed $THEME_DST (host: $host)"
    fi
    backup "$PLYCONF"
    if (( DRY )); then
        say "   [dry-run] write $PLYCONF: Theme=terminal, ShowDelay=0, DeviceScale=1"
    else
        mkdir -p "$(dirname "$PLYCONF")"
        cat > "$PLYCONF" <<'EOF'
# Managed by ~/.config/scripts/setup-boot-style.sh
[Daemon]
Theme=terminal
ShowDelay=0
# The script plugin draws text at scale 1 and would pixel-double it on HiDPI;
# the theme sizes its font from the screen height instead.
DeviceScale=1
EOF
        say "   wrote $PLYCONF"
    fi

    # -------------------------------------------------------------- 2. hook
    step "mkinitcpio hook"
    if hooks_line | grep -qw plymouth; then
        say "   plymouth already in HOOKS"
    else
        backup "$MKCONF"
        # After kms (early KMS gives plymouth the real resolution), else after
        # systemd/udev, which it needs.
        anchor=udev
        hooks_line | grep -qw systemd && anchor=systemd
        hooks_line | grep -qw kms && anchor=kms
        act "added plymouth after $anchor" sed -i -E "/^HOOKS=/{s/\\b$anchor\\b/& plymouth/}" "$MKCONF"
    fi

    # ------------------------------------------------- 2 + 3. boot entries
    step "Boot entries (splash, console palette)"
    if ! compgen -G "$ENTRIES/*.conf" >/dev/null; then
        warn "no systemd-boot entries in $ENTRIES. Add this to the kernel command line by hand:"
        warn "splash $palette_opts"
    fi
    apply_entries

    # ------------------------------------------------------ 4. console font
    step "Console font"
    if [[ ! -f /usr/share/kbd/consolefonts/$CONSOLE_FONT.psf.gz ]]; then
        warn "$CONSOLE_FONT missing (pacman -S terminus-font); keeping the current console font"
    elif grep -q "^FONT=$CONSOLE_FONT\$" "$VCONSOLE" 2>/dev/null; then
        say "   already FONT=$CONSOLE_FONT"
    else
        backup "$VCONSOLE"
        if (( DRY )); then
            say "   [dry-run] set FONT=$CONSOLE_FONT in $VCONSOLE"
        else
            sed -i '/^FONT=/d' "$VCONSOLE" 2>/dev/null || true
            echo "FONT=$CONSOLE_FONT" >> "$VCONSOLE"
            say "   set FONT=$CONSOLE_FONT in $VCONSOLE"
        fi
    fi
    hooks_line | grep -qwE 'consolefont|sd-vconsole' \
        || warn "HOOKS has neither consolefont nor sd-vconsole; the font only applies once systemd-vconsole-setup runs"

    rebuild_initramfs
fi

# ---------------------------------------------------------------- 5. greetd
if (( DO_GREETER )); then
    step "Login screen (greetd + tuigreet)"
    command="/etc/greetd/tuigreet.sh"
    host_greeter="$GREETER_SRC/$(cat /etc/hostname 2>/dev/null).lua"
    if (( DRY )); then
        say "   [dry-run] install $GREETER_SRC/tuigreet.sh -> /etc/greetd/tuigreet.sh"
    else
        install -m 755 -o root -g root "$GREETER_SRC/tuigreet.sh" /etc/greetd/tuigreet.sh
        say "   installed /etc/greetd/tuigreet.sh"
    fi
    if [[ -f $host_greeter ]]; then
        if (( DRY )); then
            say "   [dry-run] install $host_greeter -> /etc/greetd/hyprland-greeter.lua"
        else
            install -m 644 "$host_greeter" /etc/greetd/hyprland-greeter.lua
            say "   installed /etc/greetd/hyprland-greeter.lua"
        fi
        command="env HOME=/tmp XDG_CACHE_HOME=/tmp/greeter-cache Hyprland --config /etc/greetd/hyprland-greeter.lua"
    fi
    backup /etc/greetd/config.toml
    if (( DRY )); then
        say "   [dry-run] /etc/greetd/config.toml: command = \"$command\", user = \"greeter\""
    else
        cat > /etc/greetd/config.toml <<EOF
# Managed by ~/.config/scripts/setup-boot-style.sh
[terminal]
vt = 1

[default_session]
command = "$command"
user = "greeter"
EOF
        say "   wrote /etc/greetd/config.toml"
    fi
fi

step "Done"
(( DRY )) && { say "Dry run -- nothing was changed."; exit 0; }
say "Reboot to see it. Test the splash without rebooting, from a text console"
say "(Ctrl+Alt+F3, log in):"
say "  sudo plymouthd; sudo plymouth show-splash; sleep 5; sudo plymouth quit"
say "Undo the boot part: sudo $0 --undo  (backups: *.bak-$STAMP)"
