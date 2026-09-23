#!/usr/bin/env bash
# One-time root setup for the Quiet/Performance profile switch.
#
#   sudo ~/.config/scripts/setup-power-profiles.sh          apply
#   sudo ~/.config/scripts/setup-power-profiles.sh --undo   revert
#   sudo ~/.config/scripts/setup-power-profiles.sh --show    show current state
#
# Why this is needed
# ------------------
# Two things were fighting on this machine (ASUS Vivobook Pro 14X, M7400QC):
#
#  1. TLP's defaults include PLATFORM_PROFILE_ON_AC=performance, and
#     /etc/tlp.conf set CPU_SCALING_GOVERNOR/CPU_ENERGY_PERF_POLICY too. asusd
#     sets the same ACPI platform profile. Whichever ran last won, so a manual
#     profile choice was silently reverted on every AC/battery transition.
#
#  2. CPU Core Performance Boost was off, pinning scaling_max_freq to the
#     3301 MHz base clock. The 5900HX's real ceiling is 4683 MHz, so
#     "Performance" cost extra fan noise and heat for no extra speed.
#
# After this script, the ASUS platform profile is the single source of truth:
# TLP keeps doing USB/PCIe/disk/Wi-Fi power saving but no longer touches the
# CPU or the platform profile, and boost is always available -- EPP (which the
# platform profile drives) decides whether it actually gets used.
#
# TLP skips any parameter whose value is empty ("do nothing if unconfigured",
# tlp-func-cpu), and /etc/tlp.conf is parsed last, so this appended block
# overrides both the shipped defaults and anything set earlier in the file.

set -euo pipefail

readonly CONF=/etc/tlp.conf
readonly DROPIN_DIR=/etc/tlp.d
readonly BEGIN='# >>> powerprofile setup >>>'
readonly END='# <<< powerprofile setup <<<'
readonly MARK='#powerprofile-disabled# '

# CPU/platform parameters that must not be set anywhere but here, or they will
# fight the profile switch.
readonly CONFLICTING='CPU_SCALING_GOVERNOR_ON_(AC|BAT)|CPU_ENERGY_PERF_POLICY_ON_(AC|BAT|SAV)|CPU_BOOST_ON_(AC|BAT|SAV)|PLATFORM_PROFILE_ON_(AC|BAT|SAV)'

die() { echo "setup-power-profiles: $*" >&2; exit 1; }

# Comment out conflicting CPU lines in /etc/tlp.d/*.conf, leaving unrelated
# peripheral power-saving settings (RUNTIME_PM, PCIE_ASPM, ...) untouched.
neutralise_dropins() {
    local f n
    for f in "$DROPIN_DIR"/*.conf; do
        [[ -f $f ]] || continue
        n=$(grep -cE "^[[:space:]]*(${CONFLICTING})=" "$f" || true)
        (( n > 0 )) || continue
        cp -a "$f" "${f}.bak-$(date +%Y-%m-%d_%H-%M-%S)"
        # NB: '@' as the delimiter -- $CONFLICTING contains '|' alternation.
        sed -i -E "s@^([[:space:]]*(${CONFLICTING})=)@${MARK}\1@" "$f"
        echo "Disabled $n conflicting CPU line(s) in $f (original backed up)"
    done
}

restore_dropins() {
    local f n
    for f in "$DROPIN_DIR"/*.conf; do
        [[ -f $f ]] || continue
        n=$(grep -cF "$MARK" "$f" || true)
        (( n > 0 )) || continue
        sed -i "s@^${MARK}@@" "$f"
        echo "Re-enabled $n line(s) in $f"
    done
}

show_state() {
    local boost
    boost=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo '?')
    case $boost in 1) boost='1 (on)' ;; 0) boost='0 (OFF)' ;; esac
    printf '  %-22s %s\n' \
        'platform_profile'  "$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo ?)" \
        'cpu governor'      "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo ?)" \
        'energy pref (EPP)' "$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo ?)" \
        'CPU boost'         "$boost" \
        'scaling_max_freq'  "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo ?) kHz" \
        'hardware ceiling'  "$(cat /sys/devices/system/cpu/cpu0/cpufreq/amd_pstate_max_freq 2>/dev/null || echo ?) kHz"
}

if [[ ${1:-} == --show ]]; then
    echo "Current state:"; show_state
    echo
    if grep -qF "$BEGIN" "$CONF" 2>/dev/null; then
        echo "TLP block: PRESENT in $CONF"
    else
        echo "TLP block: absent from $CONF"
    fi
    echo
    echo "What TLP actually resolves to (and from where):"
    /usr/share/tlp/tlp-readconfs 2>/dev/null \
        | grep -E "(${CONFLICTING})=" | sed 's/^/  /' \
        || echo "  (could not read merged config)"
    exit 0
fi

[[ $EUID -eq 0 ]] || die "must run as root (use sudo)"
[[ -f $CONF ]]    || die "$CONF not found -- is TLP installed?"

backup="${CONF}.bak-$(date +%Y-%m-%d_%H-%M-%S)"
cp -a "$CONF" "$backup"
echo "Backed up $CONF -> $backup"

# Always drop a previous block first, so this is idempotent.
if grep -qF "$BEGIN" "$CONF"; then
    sed -i "/^${BEGIN}$/,/^${END}$/d" "$CONF"
    # collapse the trailing blank line the block leaves behind
    sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$CONF"
    echo "Removed previous managed block"
fi

if [[ ${1:-} == --undo ]]; then
    restore_dropins
    echo "Reverted $CONF to unmanaged state"
else
    neutralise_dropins
    cat >> "$CONF" <<EOF

$BEGIN
# Managed by ~/.config/scripts/setup-power-profiles.sh -- re-run it to change.
#
# The ASUS platform profile (SUPER+F1/F2, or the waybar module) is the single
# source of truth. Empty value = "TLP does not touch this".
PLATFORM_PROFILE_ON_AC=
PLATFORM_PROFILE_ON_BAT=
PLATFORM_PROFILE_ON_SAV=
CPU_SCALING_GOVERNOR_ON_AC=
CPU_SCALING_GOVERNOR_ON_BAT=
CPU_ENERGY_PERF_POLICY_ON_AC=
CPU_ENERGY_PERF_POLICY_ON_BAT=
CPU_ENERGY_PERF_POLICY_ON_SAV=
#
# Keep Core Performance Boost available in every profile; EPP decides whether
# it is used. Without this the CPU is capped at its 3301 MHz base clock.
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=1
$END
EOF
    echo "Wrote managed block to $CONF"
fi

echo "Restarting tlp..."
systemctl restart tlp

# TLP applies asynchronously; give it a moment.
sleep 2

echo
echo "State now:"
show_state

boost_now=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo '?')
if [[ ${1:-} != --undo && $boost_now != 1 ]]; then
    echo
    echo "WARNING: CPU boost is still $boost_now. Check 'tlp-stat -p' for conflicts." >&2
    exit 1
fi

echo
echo "Done. Switch profiles with SUPER+F1 (Quiet) / SUPER+F2 (Performance),"
echo "or click the waybar module. No password needed for switching."
