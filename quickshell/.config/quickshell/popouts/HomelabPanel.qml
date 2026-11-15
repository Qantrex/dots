import QtQuick
import Quickshell
import qs.services
import qs.components

// Homelab health: problems from the watchdog, approvals the agent waits for,
// and the hosts.
Column {
    id: root
    width: 360
    spacing: 10

    Component.onCompleted: Homelab.refresh()

    Item {
        width: parent.width
        height: 28
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            leftPadding: 4
            Glyph { anchors.verticalCenter: parent.verticalCenter; text: Homelab.healthy ? "󰄬" : "󰒍"; color: Homelab.healthy ? Theme.fg : Theme.love }
            Label { anchors.verticalCenter: parent.verticalCenter; text: "Homelab"; bold: true; size: Theme.fontLarge - 2 }
        }
        IconButton {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            icon: "󰑐"
            onClicked: Homelab.refresh()
        }
    }

    Column {
        width: parent.width
        visible: Homelab.problems.length > 0
        spacing: 1
        SectionTitle { width: parent.width; text: "Problems" }
        Repeater {
            model: Homelab.problems
            delegate: ListRow {
                required property var modelData
                width: parent.width
                clickable: false
                icon: "󰀦"
                title: modelData.text || String(modelData)
                titleColor: Theme.love
                value: modelData.host || ""
            }
        }
    }

    Column {
        width: parent.width
        visible: Homelab.pending.length > 0
        spacing: 1
        SectionTitle { width: parent.width; text: "Waiting for approval" }
        Repeater {
            model: Homelab.pending
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: "󰀨"
                title: modelData.text || modelData.command || modelData.summary || modelData.id || "approval"
                titleColor: Theme.gold
                onClicked: { Homelab.open("/"); Shell.close(); }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 1
        SectionTitle { width: parent.width; text: "Hosts" }
        Repeater {
            model: Homelab.state?.hosts ?? []
            delegate: ListRow {
                required property var modelData
                width: parent.width
                clickable: false
                icon: modelData.reachable ? "󰒋" : "󰒎"
                title: modelData.name || modelData.id
                value: modelData.reachable ? "up" : "down"
                valueColor: modelData.reachable ? Theme.fgMuted : Theme.love
            }
        }
    }

    MouseArea {
        width: parent.width
        height: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { Homelab.open("/"); Shell.close(); }
        Rectangle { anchors.fill: parent; radius: Theme.radiusSmall; color: parent.containsMouse ? Theme.hover : Theme.surface; border.width: 1; border.color: Theme.border }
        Label { anchors.centerIn: parent; text: "Open the agent chat"; size: Theme.fontSmall; color: Theme.iris }
    }
}
