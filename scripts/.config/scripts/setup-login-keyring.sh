#!/usr/bin/env bash
# The login password unlocks the keyring: greetd hands it to pam_gnome_keyring, which unlocks the keyring named
# "login" in the systemd gnome-keyring-daemon. Everything else that used to ask at login (ssh-unlock, rbw through
# rbw-pinentry) reads its secret from that keyring.
#   setup-login-keyring.sh             do it (asks for sudo for /etc/pam.d/greetd), then log out and back in
#   setup-login-keyring.sh --dry-run   only show what would change
# Steps, each skipped when already done:
#   1. /etc/pam.d/greetd: `auth optional pam_gnome_keyring.so` after the auth include, and
#      `session optional pam_gnome_keyring.so auto_start` after the session include (it needs XDG_RUNTIME_DIR
#      from pam_systemd). Backup: /etc/pam.d/greetd.bak-<time>. TTY login (/etc/pam.d/login) stays untouched as
#      the way back in. hyprlock needs nothing: locking the screen doesn't lock the keyring.
#   2. PAM only unlocks the keyring called "login", so an existing keyring that is the default under another
#      name (here Default_keyring) becomes login.keyring and the default. The daemon is stopped for this, so
#      apps may ask for the keyring until you log in again. Backup: <name>.keyring.bak-<time> next to it.
# It only helps if the keyring password is the login password; otherwise you get one keyring prompt, nothing lost.
# Undo: copy the backups back (sudo cp /etc/pam.d/greetd.bak-<time> /etc/pam.d/greetd; mv the keyring back and
# write its name into ~/.local/share/keyrings/default).

set -euo pipefail
dry=0; [[ ${1:-} == --dry-run ]] && dry=1
pam=${PAM_FILE:-/etc/pam.d/greetd}
kdir=${KEYRING_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/keyrings}
module=${PAM_MODULE:-/usr/lib/security/pam_gnome_keyring.so}
stamp=$(date +%Y%m%d-%H%M%S)
say() { printf '%s\n' "$*"; }

[[ $EUID -ne 0 ]] || { say "Run this as yourself, not as root (it asks for sudo itself)."; exit 1; }
[[ -f $module ]] || { say "missing $module (package gnome-keyring)"; exit 1; }
[[ -f $pam ]] || { say "missing $pam"; exit 1; }

# 1. PAM
if grep -q pam_gnome_keyring "$pam"; then
    say "1. $pam already uses pam_gnome_keyring, unchanged"
else
    new=$(mktemp)
    trap 'rm -f "$new"' EXIT
    awk '
        { print }
        $1 == "auth"    && $2 == "include" && !a { print "auth       optional     pam_gnome_keyring.so"; a = 1 }
        $1 == "session" && $2 == "include" && !s { print "session    optional     pam_gnome_keyring.so auto_start"; s = 1 }
        END { if (!a || !s) exit 3 }
    ' "$pam" >"$new" || { say "1. $pam has no auth/session include line, not touching it"; exit 1; }
    say "1. $pam:"
    diff -u "$pam" "$new" | sed -n '3,$p' || true
    if (( ! dry )); then
        sudo=sudo; [[ -n ${PAM_FILE:-} ]] && sudo=
        $sudo cp -p "$pam" "$pam.bak-$stamp"
        $sudo install -m 644 "$new" "$pam"
        grep -q 'pam_gnome_keyring.so auto_start' "$pam" || { say "   writing $pam failed"; exit 1; }
        say "   written, backup $pam.bak-$stamp"
    fi
fi

# 2. The default keyring becomes "login"
default=$(cat "$kdir/default" 2>/dev/null || true)
if [[ -f $kdir/login.keyring ]]; then
    say "2. $kdir/login.keyring exists, unchanged"
    if [[ $default != login ]]; then
        say "   default keyring is '${default:-none}', setting it to login"
        (( dry )) || printf login >"$kdir/default"
    fi
elif [[ -n $default && -f $kdir/$default.keyring ]]; then
    say "2. renaming keyring '$default' to 'login' (stops the keyring daemon until the next login)"
    if (( ! dry )); then
        if [[ -z ${KEYRING_DIR:-} ]]; then
            systemctl --user stop gnome-keyring-daemon.service gnome-keyring-daemon.socket 2>/dev/null || true
            systemctl --user stop 'dbus-*-org.freedesktop.secrets@*.service' 'dbus-*-org.gnome.keyring@*.service' \
                2>/dev/null || true
            pkill -u "$UID" -x gnome-keyring-d 2>/dev/null || true
        fi
        cp -p "$kdir/$default.keyring" "$kdir/$default.keyring.bak-$stamp"
        mv "$kdir/$default.keyring" "$kdir/login.keyring"
        printf login >"$kdir/default"
        [[ -z ${KEYRING_DIR:-} ]] && systemctl --user start gnome-keyring-daemon.socket
        say "   done, backup $kdir/$default.keyring.bak-$stamp"
    fi
else
    say "2. no default keyring found in $kdir; PAM creates 'login' at the next login"
fi

(( dry )) && { say "dry run, nothing changed"; exit 0; }
say ""
say "Now log out and log in again: that login should be the only password."
