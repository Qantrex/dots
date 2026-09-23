#!/usr/bin/env bash
# Power profile switcher for the ASUS Vivobook Pro 14X OLED (M7400QC).
#
# Switching needs no root: asusctl talks to asusd over D-Bus and polkit
# authorises it. The profile is the ASUS ACPI platform profile, which drives
# both the EC fan curve and (via amd-pstate) the CPU energy-performance
# preference:
#
#   Quiet        EPP=power            lazy fan curve   ~3600 RPM under load
#   Balanced     EPP=balance_power    medium
#   Performance  EPP=performance      aggressive       ~7300 RPM under load
#
# CPU boost is enabled persistently by TLP (see setup-power-profiles.sh); it is
# not toggled per profile, so Performance can reach the full ~4.68 GHz while
# Quiet stays pinned low by EPP and the EC's power limit.
#
# Usage:
#   powerprofile.sh quiet|balanced|performance   set a profile
#   powerprofile.sh toggle                       Quiet <-> Performance
#   powerprofile.sh cycle                        step through all three
#   powerprofile.sh get                          print the current profile
#   powerprofile.sh status                       print waybar JSON

set -uo pipefail

readonly PROFILE_FILE=/sys/firmware/acpi/platform_profile
readonly WAYBAR_SIGNAL=8

# Find a hwmon directory by its `name`. Numbering is not stable across boots,
# so never hard-code hwmonN.
hwmon_by_name() {
    local want=$1 f
    for f in /sys/class/hwmon/hwmon*/name; do
        [[ -r $f ]] || continue
        if [[ $(<"$f") == "$want" ]]; then
            dirname "$f"
            return 0
        fi
    done
    return 1
}

read_or() { [[ -r $1 ]] && cat "$1" 2>/dev/null || printf '%s' "$2"; }

current() { read_or "$PROFILE_FILE" unknown; }

icon_for() {
    # Nerd Font code points, written as \u escapes rather than literal glyphs
    # so they survive editors, terminals and copy-paste intact.
    case $1 in
        quiet)       printf '' ;;   # leaf
        balanced)    printf '' ;;   # scales
        performance) printf '' ;;   # rocket
        *)           printf '' ;;   # question mark
    esac
}

label_for() {
    case $1 in
        quiet)       printf 'Quiet' ;;
        balanced)    printf 'Balanced' ;;
        performance) printf 'Performance' ;;
        *)           printf 'Unknown' ;;
    esac
}

refresh_waybar() { pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null || true; }

set_profile() {
    local want=$1
    if ! command -v asusctl >/dev/null 2>&1; then
        echo "powerprofile: asusctl not found" >&2
        return 1
    fi
    # asusctl expects the capitalised name.
    if ! asusctl profile set "$(label_for "$want")" >/dev/null 2>&1; then
        echo "powerprofile: failed to set $want (is asusd running?)" >&2
        return 1
    fi

    # The write lands asynchronously; wait briefly for it to take effect.
    local _
    for _ in $(seq 1 20); do
        [[ $(current) == "$want" ]] && break
        sleep 0.05
    done

    refresh_waybar
    notify-send -a "Power profile" -t 2000 \
        -h "string:x-canonical-private-synchronous:powerprofile" \
        "$(icon_for "$want")  $(label_for "$want")" \
        "EPP: $(read_or /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ?)" \
        2>/dev/null || true
}

status_json() {
    local p icon label epp gov boost temp fan tooltip
    p=$(current)
    icon=$(icon_for "$p")
    label=$(label_for "$p")

    epp=$(read_or /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ?)
    gov=$(read_or /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ?)
    boost=$(read_or /sys/devices/system/cpu/cpufreq/boost ?)
    case $boost in 1) boost=on ;; 0) boost=off ;; esac

    local k10 asus
    temp="?"; fan="?"
    if k10=$(hwmon_by_name k10temp); then
        local raw; raw=$(read_or "$k10/temp1_input" "")
        [[ -n $raw ]] && temp="$(( raw / 1000 ))°C"
    fi
    if asus=$(hwmon_by_name asus); then
        local raw; raw=$(read_or "$asus/fan1_input" "")
        [[ -n $raw ]] && fan="${raw} RPM"
    fi

    tooltip="Power profile: ${label}\nEPP: ${epp}   governor: ${gov}\nCPU boost: ${boost}\nCPU temp: ${temp}   fan: ${fan}\n\nClick: Quiet <-> Performance\nScroll: cycle all profiles"

    printf '{"text":"%s %s","alt":"%s","class":"%s","tooltip":"%s"}\n' \
        "$icon" "$label" "$p" "$p" "$tooltip"
}

case "${1:-status}" in
    quiet|balanced|performance) set_profile "$1" ;;
    Quiet|Balanced|Performance) set_profile "${1,,}" ;;
    toggle)
        if [[ $(current) == performance ]]; then set_profile quiet; else set_profile performance; fi
        ;;
    cycle)
        case $(current) in
            quiet)       set_profile balanced ;;
            balanced)    set_profile performance ;;
            performance) set_profile quiet ;;
            *)           set_profile quiet ;;
        esac
        ;;
    get)    current ;;
    status) status_json ;;
    *)
        echo "usage: ${0##*/} {quiet|balanced|performance|toggle|cycle|get|status}" >&2
        exit 2
        ;;
esac
