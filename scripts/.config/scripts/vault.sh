#!/usr/bin/env bash
# Password-protected folder, unlocked once per session (gocryptfs + Bitwarden).
#
# The files are stored encrypted in ~/.vault. Unlocking mounts them decrypted
# at ~/Vault, which only exists while the vault is open. It stays open until
# `vault lock` or shutdown; logging out alone doesn't close it, since lingering
# is on and user processes outlive the session.
#
# The vault's password is a random 256-bit key that lives only in the
# Bitwarden entry "Vault (gocryptfs)", together with the gocryptfs master key
# (recovery if gocryptfs.conf is ever lost). The entry has "Master password
# re-prompt" on, so rbw asks for the master password every time the key is
# read, even while rbw is unlocked. The key goes straight from rbw into
# gocryptfs; it is never shown, typed or put on the clipboard.
#
# Usage (`vault` is an alias for this script):
#   vault init     create the vault and its Bitwarden entry (once)
#   vault [open]   unlock if needed
#   vault lock     close it again
#   vault get      print locked/unlocked
#   vault status   print waybar JSON (lock icon)

set -uo pipefail

readonly CIPHER=${VAULT_CIPHER:-$HOME/.vault}
readonly PLAIN=${VAULT_DIR:-$HOME/Vault}
readonly ENTRY=${VAULT_ENTRY:-"Vault (gocryptfs)"}
readonly WAYBAR_SIGNAL=11
SELF=$(readlink -f "${BASH_SOURCE[0]}")
readonly SELF

# `rbw add` takes the entry through $VISUAL. init points that back at this
# script, which writes the prepared entry into rbw's temp file -- no editor,
# nothing on screen.
if [[ -n ${VAULT_RBW_ENTRY:-} ]]; then
    printf '%s\n' "$VAULT_RBW_ENTRY" >"${*: -1}"
    exit
fi

# To the terminal, or as a notification when there is none (keybind).
say() {
    if [[ -t 2 ]]; then
        echo "vault: $1" >&2
    else
        notify-send -a Vault -t 4000 "Vault" "$1" 2>/dev/null || true
    fi
}

is_open() { mountpoint -q "$PLAIN"; }

current() { if is_open; then echo unlocked; else echo locked; fi; }

icon_for() {
    case $1 in
        locked)   printf '󰌾' ;;   # lock
        unlocked) printf '󰿆' ;;   # lock-open-variant
    esac
}

refresh_waybar() { pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null || true; }

status_json() {
    local s hint
    s=$(current)
    if [[ $s == locked ]]; then hint="Click: unlock and open"; else hint="Click: open\nRight-click: lock"; fi
    printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s"}\n' \
        "$(icon_for "$s")" "$s" "$s" "Vault: ${s}\n\n${hint}"
}

init() {
    if [[ -e $CIPHER/gocryptfs.conf ]]; then
        say "already set up in $CIPHER"
        return 1
    fi
    if [[ -n $(ls -A "$CIPHER" 2>/dev/null) ]]; then
        say "$CIPHER exists and isn't empty"
        return 1
    fi
    local names
    if ! names=$(rbw list); then
        say "rbw isn't working (logged in? try 'rbw unlock')"
        return 1
    fi
    if grep -qxF "$ENTRY" <<<"$names"; then
        say "Bitwarden already has an entry called \"$ENTRY\""
        return 1
    fi

    local key mk
    key=$(head -c 32 /dev/urandom | base64 -w0 | tr -d '=')
    mkdir -p "$CIPHER" && chmod 700 "$CIPHER" || return 1
    if ! gocryptfs -init -q -passfile /dev/stdin "$CIPHER" <<<"$key" >/dev/null; then
        rmdir "$CIPHER" 2>/dev/null
        say "gocryptfs -init failed"
        return 1
    fi
    mk=$(gocryptfs-xray -dumpmasterkey "$CIPHER/gocryptfs.conf" <<<"$key" 2>/dev/null)

    # The vault is still empty, so on failure undo it rather than leave one
    # whose key was never saved anywhere.
    if [[ ! $mk =~ ^[0-9a-f-]{64,}$ ]] ||
        ! VAULT_RBW_ENTRY="$key"$'\n'"gocryptfs vault in ~/.vault, opened by ~/.config/scripts/vault.sh"$'\n'"Master key (recovery if gocryptfs.conf is lost): $mk" \
            VISUAL="$SELF" EDITOR="$SELF" rbw add "$ENTRY"; then
        rm -f "$CIPHER/gocryptfs.conf" "$CIPHER/gocryptfs.diriv"
        rmdir "$CIPHER"
        say "couldn't save the key to Bitwarden, so nothing was created"
        return 1
    fi
    say "created. Now open \"$ENTRY\" in the Bitwarden app, tick \"Master password re-prompt\", save, and run 'rbw sync'."
}

unlock() {
    is_open && return 0
    if [[ ! -e $CIPHER/gocryptfs.conf ]]; then
        say "no vault yet, run 'vault init' first"
        return 1
    fi
    if [[ -n $(ls -A "$PLAIN" 2>/dev/null) ]]; then
        say "$PLAIN exists and isn't empty, move it away first"
        return 1
    fi

    mkdir -p "$PLAIN" || return 1
    rbw get "$ENTRY" | gocryptfs -q -passfile /dev/stdin "$CIPHER" "$PLAIN" 2>/dev/null
    local st=("${PIPESTATUS[@]}")
    if (( st[0] != 0 || st[1] != 0 )); then
        rmdir "$PLAIN" 2>/dev/null
        if (( st[0] != 0 )); then
            say "Bitwarden didn't hand out the key (cancelled, or wrong master password)"
        elif (( st[1] == 12 )); then
            say "the key in \"$ENTRY\" doesn't open this vault"
        else
            say "not unlocked (gocryptfs exit ${st[1]})"
        fi
        return 1
    fi
    refresh_waybar
    [[ -t 1 ]] && echo "vault: unlocked at $PLAIN"
    return 0
}

lock() {
    if ! is_open; then
        rmdir "$PLAIN" 2>/dev/null   # only if empty, i.e. our leftover mountpoint
        return 0
    fi
    if ! fusermount3 -u "$PLAIN" 2>/dev/null; then
        say "can't lock, something still uses $PLAIN (close its files and any terminal inside it)"
        return 1
    fi
    rmdir "$PLAIN"
    refresh_waybar
    say "locked"
}

case "${1:-open}" in
    init)        init ;;
    open|unlock) unlock ;;
    lock)        lock ;;
    get)         current ;;
    status)      status_json ;;
    *)
        echo "usage: ${0##*/} {init|open|lock|get|status}" >&2
        exit 2
        ;;
esac
