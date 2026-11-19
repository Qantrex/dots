pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery state and the low-battery warnings (replaces batsignal).
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: !!dev && dev.isLaptopBattery && dev.isPresent
    // UPower reports 0..1 here; guard against 0..100 in case that changes.
    readonly property real fraction: present ? (dev.percentage > 1 ? dev.percentage / 100 : dev.percentage) : 1
    readonly property int percent: Math.round(fraction * 100)
    readonly property bool charging: present && (dev.state === UPowerDeviceState.Charging
                                                 || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: present && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property bool low: present && onBattery && percent <= 30
    readonly property bool critical: present && onBattery && percent <= 15
    readonly property real watts: present ? Math.abs(dev.changeRate) : 0

    readonly property string icon: {
        if (!present) return "󰚥";
        if (charging || (!onBattery && !full)) return "󰂄";
        if (!onBattery) return "󰁹";
        const steps = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return steps[Math.min(10, Math.floor(percent / 10))];
    }

    readonly property string timeText: {
        if (!present) return "";
        const s = charging ? dev.timeToFull : (onBattery ? dev.timeToEmpty : 0);
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h + ":" + (m < 10 ? "0" : "") + m + (charging ? " to full" : " left");
    }

    // Warn once per level per discharge.
    property int warnedAt: 101
    onPercentChanged: check()
    onOnBatteryChanged: { if (!onBattery) { warnedAt = 101; Notifs.dismissApp("Battery"); } check(); }

    function check() {
        if (!present || !onBattery) return;
        if (percent <= 5 && warnedAt > 5) {
            warnedAt = 5;
            notify("critical", "Battery at " + percent + " %", "Plug in now, the laptop will shut down soon.");
        } else if (percent <= 15 && warnedAt > 15) {
            warnedAt = 15;
            notify("normal", "Battery low: " + percent + " %", timeText || "Find a charger.");
        }
    }
    function notify(urgency, summary, body) {
        // -t 60000: the critical popup goes after 60 s (Notifs.timeoutFor); plugging in closes both at once.
        Quickshell.execDetached(["notify-send", "-u", urgency, "-t", "60000", "-a", "Battery", "-i", "battery-caution", summary, body]);
    }
}
