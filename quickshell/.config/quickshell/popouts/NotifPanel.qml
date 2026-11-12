import QtQuick
import Quickshell
import qs.services
import qs.components
import qs.notifications

// Notification history, newest first. Opening it marks everything read.
Column {
    id: root
    width: 380
    spacing: 8

    Component.onCompleted: Notifs.markRead()

    Item {
        width: parent.width
        height: 28
        Label { anchors.verticalCenter: parent.verticalCenter; leftPadding: 4; text: "Notifications"; bold: true; size: Theme.fontLarge - 2 }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 2
            IconButton {
                icon: Notifs.dnd ? "󰂛" : "󰂚"
                iconColor: Notifs.dnd ? Theme.fg : Theme.fgMuted
                onClicked: Notifs.setDnd(!Notifs.dnd)
            }
            IconButton {
                visible: Notifs.list.length > 0
                icon: "󰎟"
                onClicked: Notifs.clearAll()
            }
        }
    }

    Label {
        visible: Notifs.dnd
        leftPadding: 4
        text: "Do not disturb: only critical ones pop up."
        size: Theme.fontSmall
        muted: true
    }

    Flickable {
        width: parent.width
        height: Math.min(list.implicitHeight, 520)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 6
            Repeater {
                model: Notifs.list
                delegate: NotifCard {
                    required property var modelData
                    width: list.width
                    notif: modelData
                }
            }
        }
    }

    Label {
        visible: Notifs.list.length === 0
        width: parent.width
        height: 60
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing new"
        dim: true
    }
}
