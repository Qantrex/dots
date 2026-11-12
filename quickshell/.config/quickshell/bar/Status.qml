import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import qs.components

// Network, Bluetooth, volume and battery as plain icons: one click target
// that opens the control centre. Scroll = volume. The tray sits behind a
// chevron (items that need attention show directly).
Island {
    id: root
    required property var bar
    padding: 4
    spacing: 0

    BarItem {
        id: status
        active: root.bar.isOpen("control")
        spacing: 11
        hpad: 10
        onLeftClicked: root.bar.pop("control", status)
        onMiddleClicked: Audio.toggleMute()
        onRightClicked: Quickshell.execDetached(["pavucontrol"])
        onScrolled: dir => Audio.step(dir * 0.05)

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Net.icon
            color: Net.online ? Theme.fg : Theme.fgDim
        }
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: Bt.enabled && Bt.connected.length > 0
            text: Bt.icon
        }
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.muted ? "󰝟" : (Audio.volume > 0.6 ? "󰕾" : (Audio.volume > 0.25 ? "󰖀" : "󰕿"))
            color: Audio.muted ? Theme.fgDim : Theme.fg
        }
        Row {
            visible: Power.present
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Power.icon
                color: Power.critical ? Theme.love : (Power.low ? Theme.gold : Theme.fg)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Power.onBattery
                text: Power.percent + "%"
                size: Theme.fontSmall
                color: Power.critical ? Theme.love : (Power.low ? Theme.gold : Theme.fgMuted)
                bold: Power.low
            }
        }
    }

    // Tray items that ask for attention, right in the bar.
    Repeater {
        model: SystemTray.items.values.filter(i => i.status === Status.NeedsAttention)
        delegate: BarItem {
            required property var modelData
            hpad: 6
            onLeftClicked: modelData.activate()
            onRightClicked: {
                const p = mapToItem(null, 0, height);
                modelData.display(root.bar, p.x, p.y + 4);
            }
            AppIcon { anchors.verticalCenter: parent.verticalCenter; source: modelData.icon; size: 15 }
        }
    }

    BarItem {
        id: tray
        visible: SystemTray.items.values.length > 0
        hpad: 5
        active: root.bar.isOpen("tray")
        onLeftClicked: root.bar.pop("tray", tray)
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            size: 12
            color: Theme.fgMuted
            rotation: tray.active ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.anim } }
        }
    }
}
