pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// BlueZ through Quickshell.Bluetooth.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property bool enabled: available && adapter.enabled
    readonly property var devices: available ? adapter.devices.values : []
    readonly property var connected: devices.filter(d => d.connected)
    // Paired first, then by name; unpaired ones only show while scanning.
    readonly property var list: devices.filter(d => d.paired || d.connected || (adapter && adapter.discovering))
        .slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
                                || (a.name || "").localeCompare(b.name || ""))

    readonly property string icon: !enabled ? "󰂲" : (connected.length > 0 ? "󰂱" : "󰂯")

    function toggle() { if (adapter) adapter.enabled = !adapter.enabled; }
    function scan(on) { if (adapter && adapter.enabled) adapter.discovering = on; }
    function deviceIcon(d) {
        const i = d.icon || "";
        if (i.includes("headset") || i.includes("headphone")) return "󰋋";
        if (i.includes("audio")) return "󰓃";
        if (i.includes("mouse")) return "󰍽";
        if (i.includes("keyboard")) return "󰌌";
        if (i.includes("phone")) return "󰏲";
        if (i.includes("game")) return "󰊴";
        return "󰂯";
    }
    function activate(d) {
        if (d.connected) d.disconnect();
        else if (d.paired) d.connect();
        else { d.trusted = true; d.pair(); }
    }
}
