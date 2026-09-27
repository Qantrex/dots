#!/usr/bin/env bash
# One-time root setup for the host firewall (nftables).
#
#   sudo ~/.config/scripts/setup-firewall.sh          install and enable
#   sudo ~/.config/scripts/setup-firewall.sh --undo   remove it again
#        ~/.config/scripts/setup-firewall.sh --show   show the current state
#
# Before this, nothing filtered incoming traffic: nftables was installed but
# disabled. Spotify listens on every interface (Spotify Connect discovery,
# TCP and UDP), and on a public Wi-Fi anyone could reach those ports.
#
# The policy: drop everything incoming that this machine didn't ask for, except
#   - ICMP (ping, path-MTU discovery; IPv6 breaks without neighbour discovery)
#   - DHCPv6 replies and mDNS answers (.local names, printers, Chromecasts)
#   - Tailscale: all traffic on tailscale0, plus its WireGuard port 41641 so
#     peers can connect directly instead of through a relay
#   - local VMs and containers talking to the host (virbr*, docker0, br-*)
# Outgoing traffic is not filtered.
#
# Arch's stock /etc/nftables.conf can't simply be enabled: its forward chain
# drops everything, which would cut Docker containers (SearXNG) and libvirt
# VMs off from the network. This ruleset only hooks input, lives in its own
# table and never flushes the ruleset, so Docker, libvirt and Tailscale keep
# managing their own rules, and reloading it doesn't disturb them.
#
# Side effect worth knowing: controlling this laptop's Spotify from a phone
# (Spotify Connect) needs inbound connections and won't work. The other
# direction -- this laptop playing on a speaker -- still does.

set -euo pipefail

readonly CONF=/etc/nftables.conf
readonly BACKUP=/etc/nftables.conf.arch-default
readonly TABLE="inet host_firewall"

ruleset() {
    cat <<'EOF'
#!/usr/bin/nft -f
# Host firewall, installed by ~/.config/scripts/setup-firewall.sh -- edit it there.
#
# Input only, in its own table, and no `flush ruleset`: Docker, libvirt and
# Tailscale manage their own tables and chains and must not be touched.

destroy table inet host_firewall

table inet host_firewall {
    chain input {
        type filter hook input priority filter; policy drop;

        ct state invalid drop
        ct state { established, related } accept
        iif lo accept

        meta l4proto { icmp, ipv6-icmp } accept comment "ping, PMTU, IPv6 neighbour discovery"
        ip6 saddr fe80::/10 udp sport 547 udp dport 546 accept comment "DHCPv6 replies"
        udp dport 5353 accept comment "mDNS"

        iifname "tailscale0" accept comment "tailnet"
        udp dport 41641 accept comment "Tailscale direct connections"

        iifname "virbr*" accept comment "libvirt VMs (DHCP/DNS)"
        iifname "docker0" accept comment "Docker containers"
        iifname "br-*" accept comment "Docker user networks"

        counter comment "dropped"
    }
}
EOF
}

show() {
    # The unit is a oneshot without RemainAfterExit: "inactive" after a
    # successful load is normal, so report how its last run ended instead.
    local result
    result=$(systemctl show nftables.service -p Result -p ExecMainExitTimestamp --value | paste -sd' ')
    echo "nftables.service: $(systemctl is-enabled nftables.service 2>/dev/null), last run: ${result:-never}"
    if [[ $EUID -ne 0 ]]; then
        echo "table $TABLE: reading rules needs root (sudo ${0##*/} --show)"
    elif nft list table $TABLE >/dev/null 2>&1; then
        echo "table $TABLE: loaded"
        nft list table $TABLE | grep -E 'counter packets' | sed 's/^\s*/  /'
    else
        echo "table $TABLE: not loaded"
    fi
    grep -q 'setup-firewall.sh' "$CONF" 2>/dev/null && echo "$CONF: ours" || echo "$CONF: not ours"
}

if [[ ${1:-} == --show ]]; then
    show
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo (or use --show)." >&2
    exit 1
fi

if [[ ${1:-} == --undo ]]; then
    systemctl disable --now nftables.service
    nft destroy table $TABLE
    [[ -f $BACKUP ]] && mv "$BACKUP" "$CONF"
    echo "Firewall removed; $CONF restored."
    show
    exit 0
fi

# Validate before touching anything.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
ruleset > "$tmp"
nft -c -f "$tmp"

[[ -f $BACKUP ]] || cp -a "$CONF" "$BACKUP"
install -m 644 "$tmp" "$CONF"
systemctl enable nftables.service
systemctl restart nftables.service   # runs `nft -f /etc/nftables.conf`

echo "Firewall active (original config kept as $BACKUP)."
show
