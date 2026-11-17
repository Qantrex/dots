import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Everything that used to open another program: volume and output device
// (pavucontrol), Wi-Fi (nmtui), Bluetooth (blueman), plus the laptop's power
// profile and touchpad, vault, Do Not Disturb, caffeine, and the session.
Column {
    id: root
    required property var bar
    property string expanded: ""        // wifi, bt, audio, mic, power
    property string confirm: ""         // reboot / poweroff wait for a second click

    width: 380
    spacing: 12

    function expand(what) { expanded = expanded === what ? "" : what; }

    onExpandedChanged: {
        Net.setScanning(expanded === "wifi");
        if (expanded !== "bt") Bt.scan(false);
    }
    Component.onDestruction: { Net.setScanning(false); Bt.scan(false); }

    // --- Sliders ---------------------------------------------------------
    Column {
        width: parent.width
        spacing: 2

        Row {
            width: parent.width
            Slider {
                width: parent.width - 30
                icon: Audio.muted ? "󰝟" : "󰕾"
                off: Audio.muted
                value: Audio.volume
                onMoved: v => Audio.setVolume(v)
                onIconClicked: Audio.toggleMute()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.expanded === "audio" ? "󰅀" : "󰅂"
                iconSize: 13
                onClicked: root.expand("audio")
            }
        }
        Row {
            width: parent.width
            Slider {
                width: parent.width - 30
                icon: Audio.micMuted ? "󰍭" : "󰍬"
                off: Audio.micMuted
                value: Audio.micVolume
                onMoved: v => Audio.setMicVolume(v)
                onIconClicked: Audio.toggleMic()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.expanded === "mic" ? "󰅀" : "󰅂"
                iconSize: 13
                onClicked: root.expand("mic")
            }
        }
        Slider {
            visible: Brightness.available
            width: parent.width - 30
            icon: "󰃟"
            value: Brightness.value
            onMoved: v => Brightness.set(v)
            Component.onCompleted: Brightness.refresh(false)
        }
    }

    // Output / input device lists.
    Column {
        width: parent.width
        visible: root.expanded === "audio" || root.expanded === "mic"
        spacing: 2
        SectionTitle { width: parent.width; text: root.expanded === "audio" ? "Output" : "Input" }
        Repeater {
            model: root.expanded === "audio" ? Audio.sinks : (root.expanded === "mic" ? Audio.sources : [])
            delegate: ListRow {
                required property var modelData
                readonly property bool current: modelData === (root.expanded === "audio" ? Audio.sink : Audio.source)
                width: parent.width
                icon: current ? "󰄬" : ""
                title: Audio.deviceName(modelData)
                highlighted: current
                onClicked: root.expanded === "audio" ? Audio.setSink(modelData) : Audio.setSource(modelData)
            }
        }
        // Apps playing right now, each with its own volume.
        SectionTitle { width: parent.width; text: "Apps"; visible: root.expanded === "audio" && Audio.streams.length > 0 }
        Repeater {
            model: root.expanded === "audio" ? Audio.streams : []
            delegate: Column {
                required property var modelData
                width: parent.width
                Label { text: Audio.appName(modelData); size: Theme.fontSmall; muted: true; leftPadding: 6 }
                Slider {
                    width: parent.width - 30
                    icon: modelData.audio.muted ? "󰝟" : "󰎆"
                    off: modelData.audio.muted
                    value: modelData.audio.volume
                    onMoved: v => { modelData.audio.muted = false; modelData.audio.volume = v; }
                    onIconClicked: modelData.audio.muted = !modelData.audio.muted
                }
            }
        }
    }

    // --- Tiles -----------------------------------------------------------
    GridLayout {
        width: parent.width
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        Tile {
            Layout.fillWidth: true
            icon: Net.icon
            title: "Wi-Fi"
            subtitle: Net.label
            on: Net.online
            accent: Net.online ? (Net.limited ? Theme.gold : "transparent") : (Net.wifiEnabled ? Theme.love : "transparent")
            expandable: true
            expanded: root.expanded === "wifi"
            onToggled: Net.toggleWifi()
            onExpand: root.expand("wifi")
        }
        Tile {
            Layout.fillWidth: true
            visible: Bt.available
            icon: Bt.icon
            title: "Bluetooth"
            subtitle: !Bt.enabled ? "Off" : (Bt.connected.length > 0 ? Bt.connected.map(d => d.name).join(", ") : "On")
            on: Bt.enabled
            expandable: true
            expanded: root.expanded === "bt"
            onToggled: Bt.toggle()
            onExpand: root.expand("bt")
        }
        Tile {
            Layout.fillWidth: true
            visible: Scripts.powerprofile.enabled
            readonly property string p: Scripts.powerprofile.state
            icon: p === "performance" ? "󰓅" : (p === "balanced" ? "󰾅" : "󰾆")
            title: "Power"
            subtitle: p ? p.charAt(0).toUpperCase() + p.slice(1) : "…"
            on: p === "performance"
            expandable: true
            expanded: root.expanded === "power"
            onToggled: Scripts.run("powerprofile", ["toggle"])
            onExpand: root.expand("power")
        }
        Tile {
            Layout.fillWidth: true
            visible: Scripts.touchpad.enabled
            icon: Scripts.touchpad.state === "off" ? "󰍾" : "󰟸"
            title: "Touchpad"
            subtitle: Scripts.touchpad.state === "off" ? "Off" : "On"
            on: Scripts.touchpad.state !== "off"
            onToggled: Scripts.run("touchpad", ["toggle"])
        }
        Tile {
            Layout.fillWidth: true
            readonly property bool unlocked: Scripts.vault.loaded && Scripts.vault.state !== "locked"
            icon: unlocked ? "󰌿" : "󰌾"
            title: "Vault"
            subtitle: unlocked ? "Open · click to lock" : "Locked"
            on: unlocked
            onToggled: unlocked ? Scripts.run("vault", ["lock"])
                                : Scripts.runThen("vault", ["open"], "xdg-open ~/Vault")
        }
        Tile {
            Layout.fillWidth: true
            icon: Notifs.dnd ? "󰂛" : "󰂚"
            title: "Do not disturb"
            subtitle: Notifs.dnd ? "On" : "Off"
            on: Notifs.dnd
            onToggled: Notifs.setDnd(!Notifs.dnd)
        }
        Tile {
            Layout.fillWidth: true
            icon: "󰅶"
            title: "Caffeine"
            subtitle: Shell.caffeine ? "Stays awake" : "Off"
            on: Shell.caffeine
            onToggled: Shell.setCaffeine(!Shell.caffeine)
        }
        Tile {
            Layout.fillWidth: true
            visible: Scripts.ai.enabled
            icon: "󰚩"
            title: "Local AI"
            subtitle: Scripts.ai.has("busy") ? "Busy" : (Scripts.ai.has("starting") ? "Starting…" : (Scripts.ai.has("off") ? "Off" : "On"))
            on: !Scripts.ai.has("off")
            onToggled: Scripts.run("ai", ["toggle"])
        }
    }

    // --- Detail lists ------------------------------------------------------
    WifiList { width: parent.width; visible: root.expanded === "wifi" }

    Column {
        width: parent.width
        visible: root.expanded === "bt"
        spacing: 2
        SectionTitle {
            width: parent.width
            text: "Devices"
            action: Bt.adapter && Bt.adapter.discovering ? "Stop scan" : "Scan"
            onActionClicked: Bt.scan(!(Bt.adapter && Bt.adapter.discovering))
        }
        Repeater {
            model: root.expanded === "bt" ? Bt.list : []
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: Bt.deviceIcon(modelData)
                title: modelData.name || modelData.address
                subtitle: modelData.pairing ? "Pairing…" : (modelData.state === 3 ? "Connecting…" : (modelData.paired ? "" : "Not paired"))
                value: modelData.connected ? (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : "Connected") : ""
                highlighted: modelData.connected
                onClicked: Bt.activate(modelData)
            }
        }
        Label { visible: Bt.list.length === 0; text: Bt.enabled ? "No devices" : "Bluetooth is off"; muted: true; leftPadding: 6 }
    }

    Column {
        width: parent.width
        visible: root.expanded === "power"
        spacing: 2
        Repeater {
            model: [["quiet", "Quiet", "󰾆", "Lazy fans, low power"], ["balanced", "Balanced", "󰾅", "The middle setting"],
                    ["performance", "Performance", "󰓅", "Full boost, loud fans"]]
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: modelData[2]
                title: modelData[1]
                subtitle: modelData[3]
                highlighted: Scripts.powerprofile.state === modelData[0]
                onClicked: Scripts.run("powerprofile", [modelData[0]])
            }
        }
    }

    // --- Battery and session --------------------------------------------
    Rectangle { width: parent.width; height: 1; color: Theme.border }

    Item {
        width: parent.width
        implicitHeight: 32

        Row {
            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
            width: parent.width - sessionRow.width - 12
            spacing: 8
            visible: Power.present
            Glyph { anchors.verticalCenter: parent.verticalCenter; text: Power.icon; color: Power.critical ? Theme.love : (Power.low ? Theme.gold : Theme.fg) }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28
                text: Power.percent + "%" + (Power.timeText ? " · " + Power.timeText : (Power.full ? " · full" : ""))
                size: Theme.fontSmall
                muted: true
            }
        }

        Row {
            id: sessionRow
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 0
            IconButton {
                icon: "󰂚"
                onClicked: Shell.toggle("notifs", root.bar.screen.name, Shell.popoutX)
                Rectangle {
                    visible: Notifs.unread > 0
                    width: 7; height: 7; radius: 4
                    color: Theme.accent
                    anchors { right: parent.right; top: parent.top; margins: 5 }
                }
            }
            IconButton { icon: "󰍛"; onClicked: Shell.toggle("system", root.bar.screen.name, Shell.popoutX) }
            IconButton { icon: "󰌾"; onClicked: { Shell.close(); Quickshell.execDetached(["hyprlock"]); } }
            IconButton { icon: "󰤄"; onClicked: { Shell.close(); Quickshell.execDetached(["systemctl", "suspend"]); } }
            IconButton {
                icon: "󰜉"
                iconColor: root.confirm === "reboot" ? Theme.gold : Theme.fg
                onClicked: root.confirm === "reboot" ? Quickshell.execDetached(["systemctl", "reboot"]) : (root.confirm = "reboot", confirmTimer.restart())
            }
            IconButton {
                icon: "󰐥"
                iconColor: root.confirm === "poweroff" ? Theme.love : Theme.fg
                onClicked: root.confirm === "poweroff" ? Quickshell.execDetached(["systemctl", "poweroff"]) : (root.confirm = "poweroff", confirmTimer.restart())
            }
        }
    }
    Label {
        visible: root.confirm !== ""
        width: parent.width
        horizontalAlignment: Text.AlignRight
        text: "Click again to " + (root.confirm === "reboot" ? "restart" : "shut down")
        size: Theme.fontSmall
        color: root.confirm === "reboot" ? Theme.gold : Theme.love
    }
    Timer { id: confirmTimer; interval: 3000; onTriggered: root.confirm = "" }
}
