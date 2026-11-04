#!/usr/bin/env bash
# One-time root setup for pc-quiet (desktop bauarch-pc only).
#
#   sudo ~/.config/scripts/setup-pc-quiet.sh          install
#   sudo ~/.config/scripts/setup-pc-quiet.sh --undo   remove
#
# Copies pc-quiet to /usr/local/sbin (root-owned, so the sudoers line can't be
# abused by editing the file in ~) and lets the user run exactly
# `pc-quiet on|off|status` without a password. `away` uses it.

set -euo pipefail

readonly SRC="$(dirname "$(readlink -f "$0")")/pc-quiet"
readonly DST=/usr/local/sbin/pc-quiet
readonly SUDOERS=/etc/sudoers.d/pc-quiet

[[ $EUID -eq 0 ]] || { echo "setup-pc-quiet: run with sudo" >&2; exit 1; }
user=${SUDO_USER:?run through sudo, not as root directly}

if [[ ${1:-} == --undo ]]; then
    "$DST" off 2>/dev/null || true
    rm -f "$DST" "$SUDOERS"
    echo "Removed $DST and $SUDOERS"
    exit 0
fi

install -m 0755 -o root -g root "$SRC" "$DST"

tmp=$(mktemp)
cat >"$tmp" <<EOF
# Managed by ~/.config/scripts/setup-pc-quiet.sh
$user ALL=(root) NOPASSWD: $DST on, $DST off, $DST status
EOF
visudo -cf "$tmp" >/dev/null
install -m 0440 -o root -g root "$tmp" "$SUDOERS"
rm -f "$tmp"

echo "Installed $DST and $SUDOERS"
"$DST" status
