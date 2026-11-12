pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// NetworkManager through Quickshell.Networking.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null

    readonly property var wifiNetworks: wifi ? wifi.networks.values : []
    readonly property var active: wifiNetworks.find(n => n.connected) ?? null
    // Sorted for the list: connected first, then known, then by signal.
    readonly property var wifiList: wifiNetworks.slice().sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool online: !!wired || !!active
    readonly property bool limited: online && (Networking.connectivity === NetworkConnectivity.Limited
                                               || Networking.connectivity === NetworkConnectivity.Portal)
    readonly property real strength: active ? active.signalStrength : 0
    readonly property string label: wired ? "Wired" : (active ? active.name : (wifiEnabled ? "Disconnected" : "Wi-Fi off"))

    // Nerd Font glyphs (nf-md-wifi_strength_*).
    readonly property string icon: {
        if (wired) return "󰈀";
        if (!wifiEnabled) return "󰤮";
        if (!active) return "󰤯";
        return strengthIcon(strength);
    }
    function strengthIcon(s) {
        if (s > 0.75) return "󰤨";
        if (s > 0.5) return "󰤥";
        if (s > 0.25) return "󰤢";
        return "󰤟";
    }

    function setScanning(on) { if (wifi) wifi.scannerEnabled = on; }
    function toggleWifi() { Networking.wifiEnabled = !Networking.wifiEnabled; }
}
