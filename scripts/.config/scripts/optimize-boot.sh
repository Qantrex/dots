#!/usr/bin/env bash
# One-time boot-time optimisation for this machine.
#
#   sudo ~/.config/scripts/optimize-boot.sh            apply
#   sudo ~/.config/scripts/optimize-boot.sh --dry-run  show what would change
#        ~/.config/scripts/optimize-boot.sh --show     current state (no root)
#
# Measured before:  4.790s firmware + 2.738s loader + 7.121s kernel
#                 + 5.493s userspace = 20.144s
#
# What it changes
# ---------------
# 1. Kernel cmdline said "quit splash". That is a typo for "quiet" -- "quit" is
#    not a kernel parameter, so the console was never actually quietened.
#
# 2. Adds a fallback boot entry. initramfs-linux-fallback.img already exists but
#    nothing referenced it, and loader.conf has "timeout 0", so there was no way
#    to boot anything else if the main initramfs broke. Hold Space during boot
#    to get the menu.
#
# 3. Wires up amd-ucode if installed. Neither microcode package was present on
#    an AMD Ryzen, so the CPU was running without microcode updates. The
#    "microcode" hook is already in HOOKS; the boot entry just needs the
#    initrd line, which must come before the main initramfs.
#
# 4. Trims the initramfs for the current GPU mode. envycontrol is in
#    "integrated" mode, which blacklists the NVIDIA modules -- yet mkinitcpio
#    still packed them plus ~109 MB of GSP firmware. Measured: 142 MB -> 48 MB,
#    and decompression 0.220s -> 0.041s. `gpumode on/off` now keeps this in
#    sync, so this step is only for the first run.
#
# 5. Socket-activates docker and libvirtd. docker.service sat directly on the
#    critical chain to graphical.target at 2.1s. Both still start on first use.
#    NOTE: containers with restart:always and VMs marked autostart will no
#    longer come up by themselves at boot.

set -euo pipefail

readonly ENTRY=/boot/loader/entries/arch.conf
readonly FALLBACK_ENTRY=/boot/loader/entries/arch-fallback.conf
readonly MKCONF=/etc/mkinitcpio.conf
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"

DRY=0
[[ ${1:-} == --dry-run ]] && DRY=1

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
run()  { if (( DRY )); then printf '   [dry-run] %s\n' "$*"; else eval "$*"; fi; }

show_state() {
    say "Boot timing:"
    systemd-analyze 2>/dev/null | sed 's/^/  /'
    say ""
    say "initramfs:     $(du -h /boot/initramfs-linux.img 2>/dev/null | cut -f1)"
    say "MODULES:       $(grep -E '^MODULES=' "$MKCONF" 2>/dev/null)"
    say "GPU mode:      $(envycontrol -q 2>/dev/null || echo '?')"
    say "cmdline:       $(cat /proc/cmdline)"
    say "microcode:     $(pacman -Q amd-ucode 2>/dev/null || echo 'amd-ucode NOT installed')"
    say "fallback entry: $([[ -f $FALLBACK_ENTRY ]] && echo present || echo absent)"
    say "docker:        $(systemctl is-enabled docker.service 2>&1) / socket $(systemctl is-enabled docker.socket 2>&1)"
    say "libvirtd:      $(systemctl is-enabled libvirtd.service 2>&1) / socket $(systemctl is-enabled libvirtd.socket 2>&1)"
}

if [[ ${1:-} == --show ]]; then
    show_state
    exit 0
fi

[[ $EUID -eq 0 ]] || { echo "must run as root (use sudo)" >&2; exit 1; }
[[ -f $ENTRY ]]   || { echo "$ENTRY not found -- is this systemd-boot?" >&2; exit 1; }

say "Backing up to *.bak-$STAMP"
run "cp -a '$ENTRY' '$ENTRY.bak-$STAMP'"
run "cp -a '$MKCONF' '$MKCONF.bak-$STAMP'"

# ---------------------------------------------------------------- 1. cmdline
step "Kernel cmdline"
if grep -qE '(^| )quit( |$)' "$ENTRY"; then
    run "sed -i 's/\\bquit\\b/quiet/' '$ENTRY'"
    say "   fixed 'quit' -> 'quiet'"
else
    say "   already correct"
fi

# -------------------------------------------------------------- 2. microcode
step "Microcode"
if pacman -Q amd-ucode >/dev/null 2>&1; then
    if grep -q '^initrd .*amd-ucode' "$ENTRY"; then
        say "   amd-ucode already referenced"
    else
        # must precede the main initramfs line
        run "sed -i '0,/^initrd /s||initrd /amd-ucode.img\\ninitrd |' '$ENTRY'"
        say "   added 'initrd /amd-ucode.img'"
    fi
else
    say "   amd-ucode NOT installed -- run 'pacman -S amd-ucode', then re-run this script"
fi

# --------------------------------------------------------- 3. fallback entry
step "Fallback boot entry"
if [[ -f $FALLBACK_ENTRY ]]; then
    say "   already present"
elif [[ ! -f /boot/initramfs-linux-fallback.img ]]; then
    say "   no fallback image on disk; skipping"
else
    # Same options, but the fallback initramfs and a visible console. Strips
    # the "quit" typo too, in case this runs before step 1 has fixed it.
    opts="$(grep -E '^options ' "$ENTRY" | head -1 \
        | sed 's/^options //; s/\bquiet\b//; s/\bquit\b//; s/\bsplash\b//; s/  */ /g; s/ $//')"
    if (( DRY )); then
        say "   [dry-run] would write $FALLBACK_ENTRY"
    else
        {
            echo "title   NYARCH (fallback)"
            echo "linux   /vmlinuz-linux"
            pacman -Q amd-ucode >/dev/null 2>&1 && echo "initrd  /amd-ucode.img"
            echo "initrd  /initramfs-linux-fallback.img"
            echo "options $opts"
        } > "$FALLBACK_ENTRY"
        say "   created $FALLBACK_ENTRY (hold Space at boot for the menu)"
    fi
fi

# ------------------------------------------------------------- 4. initramfs
step "initramfs for the current GPU mode"
mode="$(envycontrol -q 2>/dev/null || echo unknown)"
say "   envycontrol mode: $mode"
if [[ $mode == integrated ]]; then
    if grep -qE '^MODULES=\(\s*\)' "$MKCONF"; then
        say "   MODULES already empty"
    else
        run "sed -i 's|^MODULES=.*|MODULES=()|' '$MKCONF'"
        say "   set MODULES=() -- nvidia is blacklisted in this mode anyway"
    fi
    before="$(stat -c %s /boot/initramfs-linux.img 2>/dev/null || echo 0)"
    run "mkinitcpio -P"
    if (( ! DRY )); then
        after="$(stat -c %s /boot/initramfs-linux.img)"
        printf '   initramfs %s -> %s\n' \
            "$(numfmt --to=iec "$before")" "$(numfmt --to=iec "$after")"
    fi
else
    say "   not integrated mode; leaving MODULES alone"
fi

# --------------------------------------------------------- 5. lazy services
step "Deferring services to socket activation"
#
# `systemctl disable X.service` also disables everything in the unit's Also=
# list. libvirtd.service lists virtlogd.socket and virtlockd.socket there, and
# it Requires= virtlogd.socket -- so a naive disable/enable pair silently
# leaves virtlogd and virtlockd disabled and VMs fail to start on the next
# boot. Snapshot which sockets are enabled first, then restore exactly those.
for svc in docker libvirtd; do
    if ! systemctl cat "${svc}.socket" >/dev/null 2>&1; then
        say "   ${svc}.socket not available; skipping"
        continue
    fi
    if [[ "$(systemctl is-enabled "${svc}.service" 2>&1)" != enabled ]]; then
        say "   ${svc}.service not enabled; leaving alone"
        continue
    fi

    # Snapshot every enabled socket, disable, then re-enable whatever the
    # disable took with it. Also= chains nest (libvirtd -> virtlogd ->
    # virtlogd-admin), so enumerating the service's own directives is not
    # enough -- diffing the before/after state catches all of it.
    enabled_sockets() {
        systemctl list-unit-files --no-legend --state=enabled '*.socket' 2>/dev/null \
            | awk '{print $1}' | sort
    }

    if (( DRY )); then
        say "   [dry-run] would disable ${svc}.service and keep its sockets enabled"
        continue
    fi

    before_socks="$(enabled_sockets)"
    systemctl disable "${svc}.service"
    systemctl enable "${svc}.socket" >/dev/null 2>&1 || true
    after_socks="$(enabled_sockets)"

    mapfile -t lost < <(comm -23 <(printf '%s\n' "$before_socks") <(printf '%s\n' "$after_socks"))
    if (( ${#lost[@]} )); then
        systemctl enable "${lost[@]}" >/dev/null 2>&1 || true
        say "   ${svc}: service disabled; restored ${lost[*]}"
    else
        say "   ${svc}: service disabled, ${svc}.socket enabled"
    fi
done

step "Done"
(( DRY )) && { say "Dry run -- nothing was changed."; exit 0; }
say ""
show_state
say ""
say "Reboot to measure. To undo:"
say "  cp $ENTRY.bak-$STAMP $ENTRY"
say "  cp $MKCONF.bak-$STAMP $MKCONF && mkinitcpio -P"
say "  rm -f $FALLBACK_ENTRY"
say "  systemctl enable docker.service libvirtd.service"
