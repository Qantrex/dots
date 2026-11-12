import QtQuick
import Quickshell
import qs.services
import qs.components

// Clock (+ the soonest deadline when it is due within 2 days), and the media
// player while it plays (and for 5 minutes after a pause).
Island {
    id: root
    required property var bar
    padding: 4
    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarItem {
        id: clockItem
        active: root.bar.isOpen("day")
        onLeftClicked: root.bar.pop("day", clockItem)
        tip: Qt.formatDate(clock.date, "dddd, d MMMM yyyy") + (Homelab.urgent ? "\n" + Homelab.urgent.title + " · " + Homelab.dayWord(Homelab.urgent.days) : "")
        spacing: 8

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            bold: true
            font.letterSpacing: 0.5
        }
        Row {
            visible: Homelab.urgent !== null
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Label { text: "·"; dim: true }
            Label {
                readonly property var d: Homelab.urgent
                text: d ? Homelab.shortTitle(d) + " " + Homelab.dayWord(d.days) : ""
                color: d && d.days === 0 ? Theme.gold : Theme.fgMuted
                size: Theme.fontSmall + 1
            }
        }
    }

    // Media.
    Rectangle {
        visible: mediaItem.visible
        width: 1; height: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.border
    }

    BarItem {
        id: mediaItem
        property bool recent: false
        visible: Media.player !== null && (Media.active || recent) && Media.title !== ""
        active: root.bar.isOpen("media")
        spacing: 7
        onLeftClicked: root.bar.pop("media", mediaItem)
        onMiddleClicked: Media.toggle()
        onScrolled: dir => dir > 0 ? Media.previous() : Media.next()
        tip: (Media.player ? Media.player.identity + (Media.active ? "" : " (paused)") : "") + "\nMiddle: play/pause · scroll: previous/next"

        Connections {
            target: Media
            function onActiveChanged() {
                if (Media.active) { mediaItem.recent = true; hideTimer.stop(); }
                else hideTimer.restart();
            }
        }
        Timer { id: hideTimer; interval: 300000; onTriggered: mediaItem.recent = false }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Media.active ? "󰏤" : "󰐊"
            size: 12
            color: Media.active ? Theme.fg : Theme.fgDim
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 280)
            text: Media.title + (Media.artist ? "  ·  " + Media.artist : "")
            color: Media.active ? Theme.fgMuted : Theme.fgDim
            size: Theme.fontSmall + 1
        }
    }
}
