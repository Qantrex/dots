#!/usr/bin/env bash
# Periodic system maintenance for this machine.
#
#   sudo ~/.config/scripts/maintain.sh            apply
#   sudo ~/.config/scripts/maintain.sh --dry-run  show what would change
#        ~/.config/scripts/maintain.sh --show     current state (no root)
#
# Safe to re-run: every step checks before acting. Nothing here removes
# packages or user data -- orphans are only reported, never removed, because
# "orphan" means nothing depends on it, not that you don't use it directly
# (dotnet-sdk, clang, doxygen and friends all show up as orphans).

set -euo pipefail

readonly FSTAB=/etc/fstab
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"

DRY=0
[[ ${1:-} == --dry-run ]] && DRY=1

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
run()  { if (( DRY )); then printf '   [dry-run] %s\n' "$*"; else eval "$*"; fi; }

human() { numfmt --to=iec --suffix=B "${1:-0}" 2>/dev/null || echo "${1:-0}"; }

cache_bytes() { du -sb /var/cache/pacman/pkg 2>/dev/null | cut -f1 || echo 0; }

show_state() {
    say "Disk:"
    df -h / /boot 2>/dev/null | sed 's/^/  /'
    say ""
    say "pacman cache:    $(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)  ($(find /var/cache/pacman/pkg -name '*.pkg.tar*' 2>/dev/null | wc -l) files)"
    say "paccache.timer:  $(systemctl is-enabled paccache.timer 2>&1)"
    say "fstrim.timer:    $(systemctl is-enabled fstrim.timer 2>&1)"
    say "orphans:         $(pacman -Qtdq 2>/dev/null | wc -l)"
    say "journal:         $(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMG]' | head -1)"
    say "/boot perms:     $(stat -c %A /boot 2>/dev/null)  (vfat: set by fmask/dmask in fstab)"
    say "sslh generator:  $([[ -L /etc/systemd/system-generators/systemd-sslh-generator ]] && echo masked || echo 'active (crashes each boot)')"
    say "nvidia modload:  $(
        if [[ ! -f /usr/lib/modules-load.d/nvidia-utils.conf ]]; then
            echo 'n/a (nvidia-utils no longer ships it)'
        elif [[ -L /etc/modules-load.d/nvidia-utils.conf ]]; then
            echo masked
        else
            echo active
        fi)"
    say "failed units:    $(systemctl --failed --no-legend 2>/dev/null | wc -l)"
}

if [[ ${1:-} == --show ]]; then
    show_state
    exit 0
fi

[[ $EUID -eq 0 ]] || { echo "must run as root (use sudo)" >&2; exit 1; }

before_cache="$(cache_bytes)"

# ------------------------------------------------------------ pacman cache
# pacman never prunes /var/cache/pacman/pkg -- it keeps every version ever
# downloaded so you can roll back with `pacman -U`. Useful, but unbounded:
# this machine had 108 GB across 21420 files, including 50 versions each of
# ollama-cuda, ollama and linux. Two versions back is plenty.
step "pacman cache"
if ! command -v paccache >/dev/null 2>&1; then
    say "   paccache missing -- install pacman-contrib first:"
    say "     pacman -Syu && pacman -S pacman-contrib"
    say "   (use -Syu, not -Sy: refreshing the db without upgrading leaves"
    say "    you in a partial-upgrade state)"
else
    say "   before: $(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"
    run "paccache -rk2"     # keep 2 newest of installed packages
    run "paccache -ruk0"    # drop everything for uninstalled packages
    if ! systemctl is-enabled paccache.timer >/dev/null 2>&1; then
        run "systemctl enable --now paccache.timer"
        say "   enabled paccache.timer (weekly, keeps it from regrowing)"
    else
        say "   paccache.timer already enabled"
    fi
fi

# ----------------------------------------------------------------- fstrim
# SSDs erase in large blocks but write in small pages. Deleting a file only
# updates the filesystem -- without TRIM the drive keeps preserving pages
# nobody wants, its pool of pre-erased blocks shrinks, and writes start
# costing read-modify-erase-write. Weekly batch discard fixes that.
step "SSD TRIM"
if [[ "$(systemctl is-enabled fstrim.timer 2>&1)" == enabled ]]; then
    say "   fstrim.timer already enabled"
else
    run "systemctl enable --now fstrim.timer"
    say "   enabled fstrim.timer (weekly)"
fi

# ------------------------------------------------------- crashing generator
# systemd generators run very early in boot. This one aborts every time.
# sslh is only present as a blackarch-officials dependency; masking the
# generator stops the crash without touching the package.
step "sslh generator (SIGABRT every boot)"
GEN=/etc/systemd/system-generators/systemd-sslh-generator
if [[ ! -f /usr/lib/systemd/system-generators/systemd-sslh-generator ]]; then
    say "   not installed; nothing to do"
elif [[ -L $GEN ]]; then
    say "   already masked"
else
    run "mkdir -p /etc/systemd/system-generators"
    run "ln -sf /dev/null '$GEN'"
    say "   masked (unmask: rm $GEN)"
fi

# --------------------------------------------------- nvidia-utils modprobe
# nvidia-utils ships a modules-load.d entry for nvidia-uvm. In envycontrol's
# integrated mode the blacklist has `alias nvidia_uvm off`, so modprobe
# resolves it to a literal module named "off" and logs an error every boot.
# An /etc file of the same name shadows the /usr/lib one.
step "nvidia-utils modules-load ('could not find module by name=off')"
NVML=/etc/modules-load.d/nvidia-utils.conf
if [[ ! -f /usr/lib/modules-load.d/nvidia-utils.conf ]]; then
    say "   not present; nothing to do"
elif [[ -L $NVML ]]; then
    say "   already masked"
elif [[ "$(envycontrol -q 2>/dev/null)" != integrated ]]; then
    say "   GPU is not in integrated mode; leaving it alone"
else
    run "mkdir -p /etc/modules-load.d"
    run "ln -sf /dev/null '$NVML'"
    say "   masked (unmask: rm $NVML -- do that if you switch to gpumode on)"
fi

# ------------------------------------------------------------ /boot perms
# bootctl warns that /boot/loader/random-seed is world readable. /boot is
# vfat, where chmod is a no-op -- permissions come from the fmask/dmask mount
# options, so this has to be fixed in fstab.
step "/boot permissions (random-seed is world readable)"
if ! grep -qE '^[^#].*[[:space:]]/boot[[:space:]].*vfat' "$FSTAB"; then
    say "   no vfat /boot line in fstab; skipping"
elif grep -qE '^[^#].*[[:space:]]/boot[[:space:]].*fmask=0077' "$FSTAB"; then
    say "   already fmask=0077,dmask=0077"
else
    run "cp -a '$FSTAB' '$FSTAB.bak-$STAMP'"
    run "sed -i '\\|[[:space:]]/boot[[:space:]]|{s/fmask=0022/fmask=0077/; s/dmask=0022/dmask=0077/}' '$FSTAB'"
    if (( ! DRY )); then
        if ! findmnt --verify >/dev/null 2>&1; then
            cp -a "$FSTAB.bak-$STAMP" "$FSTAB"
            say "   fstab failed validation; restored from backup" >&2
        else
            mount -o remount /boot 2>/dev/null || true
            # vfat cannot change fmask/dmask on a remount -- the kernel keeps
            # the mask it was mounted with. Check whether it actually took
            # rather than assuming, and say so plainly if it did not.
            if findmnt -n -o OPTIONS /boot | grep -q 'fmask=0077'; then
                say "   set fmask=0077,dmask=0077, applied now -> $(stat -c %A /boot)"
            else
                say "   fstab updated to fmask=0077,dmask=0077."
                say "   vfat cannot change the mask on remount, so /boot is still"
                say "   $(stat -c %A /boot) until the next boot. No action needed."
            fi
        fi
    fi
fi

# --------------------------------------------------------------- reporting
step "Orphans (reported only -- review before removing)"
orphans="$(pacman -Qtdq 2>/dev/null || true)"
if [[ -z $orphans ]]; then
    say "   none"
else
    say "   $(printf '%s\n' "$orphans" | wc -l) orphaned packages."
    debug_n="$(printf '%s\n' "$orphans" | grep -c -- '-debug$' || true)"
    say "   $debug_n are -debug artifacts and safe to drop:"
    say "     pacman -Qtdq | grep -- '-debug\$' | pacman -Rns -"
    say "   Review the rest by hand -- toolchains you use directly (dotnet-sdk,"
    say "   clang, doxygen, ant) legitimately have nothing depending on them:"
    say "     pacman -Qtdq | grep -v -- '-debug\$'"
fi

step "Done"
if (( DRY )); then
    say "Dry run -- nothing was changed."
    exit 0
fi
after_cache="$(cache_bytes)"
if (( before_cache > after_cache )); then
    say "Reclaimed $(human $(( before_cache - after_cache ))) from the pacman cache."
fi
say ""
show_state
