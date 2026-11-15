import QtQuick
import Quickshell
import qs.services
import qs.components

// CPU, memory, temperature and fan; on the desktop also the GPU (AI node).
Column {
    id: root
    width: 320
    spacing: 10

    Component.onCompleted: Sys.detailed = true
    Component.onDestruction: Sys.detailed = false

    component Meter: Column {
        id: m
        property string icon
        property string title
        property string value
        property real fraction: 0
        property color barColor: fraction >= 0.9 ? Theme.love : (fraction >= 0.8 ? Theme.gold : Theme.fg)
        width: root.width
        spacing: 4
        Item {
            width: parent.width
            height: 18
            Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                Glyph { text: m.icon; color: Theme.fgMuted; size: 14 }
                Label { text: m.title }
            }
            Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: m.value; muted: true; size: Theme.fontSmall }
        }
        Rectangle {
            width: parent.width; height: 4; radius: 2
            color: Theme.track
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, m.fraction))
                height: parent.height; radius: 2
                color: m.barColor
                Behavior on width { NumberAnimation { duration: Theme.anim } }
            }
        }
    }

    Meter {
        icon: "󰻠"; title: "CPU"
        fraction: Sys.cpu
        value: Math.round(Sys.cpu * 100) + "%" + (Sys.temp >= 0 ? " · " + Sys.temp + "°C" : "")
    }
    Meter {
        icon: "󰍛"; title: "Memory"
        fraction: Sys.memFraction
        value: Sys.memUsed.toFixed(1) + " / " + Sys.memTotal.toFixed(1) + " GB"
    }
    Meter {
        visible: Sys.gpu !== null
        icon: "󰢮"; title: "GPU"
        fraction: Sys.gpu ? Sys.gpu.util : 0
        value: Sys.gpu ? Math.round(Sys.gpu.util * 100) + "% · " + Sys.gpu.temp + "°C" : ""
    }
    Meter {
        visible: Sys.gpu !== null
        icon: "󰘚"; title: "VRAM"
        fraction: Sys.gpu ? Sys.gpu.memUsed / Sys.gpu.memTotal : 0
        value: Sys.gpu ? Sys.gpu.memUsed.toFixed(1) + " / " + Sys.gpu.memTotal.toFixed(1) + " GB" : ""
    }

    Item {
        width: parent.width
        height: 30
        Label {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 4
            visible: Sys.fan >= 0
            text: "󰈐  " + Sys.fan + " RPM"
            muted: true
            size: Theme.fontSmall
        }
        MouseArea {
            id: btop
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: bl.implicitWidth + 20; height: 28
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Shell.close(); Quickshell.execDetached(["foot", "-e", "btop"]); }
            Rectangle { anchors.fill: parent; radius: Theme.radiusSmall; color: btop.containsMouse ? Theme.hover : Theme.surface; border.width: 1; border.color: Theme.border }
            Label { id: bl; anchors.centerIn: parent; text: "btop"; size: Theme.fontSmall }
        }
    }
}
