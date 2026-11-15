import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services
import qs.components

// One notification: icon or image, app and summary, body, action buttons.
// Critical ones get a love border; a click on the body runs the default action.
Rectangle {
    id: root
    required property var notif
    property bool popup: false
    signal closeRequested()

    readonly property bool critical: notif && notif.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: notif ? notif.actions.find(a => a.identifier === "default") : null
    readonly property var buttons: notif ? notif.actions.filter(a => a.identifier !== "default") : []
    readonly property string icon: notif ? Notifs.icon(notif) : ""

    implicitWidth: 440
    implicitHeight: col.implicitHeight + 32
    radius: Theme.radius
    color: popup ? Theme.bg : Theme.surface
    border.width: 1
    border.color: critical ? Theme.love : (popup ? Theme.borderStrong : Theme.border)

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => {
            if (m.button === Qt.LeftButton && root.defaultAction) {
                root.defaultAction.invoke();
            } else if (m.button === Qt.LeftButton && root.popup) {
                root.closeRequested();       // a popup without action: just hide it
                return;
            }
            if (m.button !== Qt.LeftButton || root.defaultAction) root.notif.dismiss();
        }
    }

    Row {
        id: row
        anchors { fill: parent; margins: 16 }
        spacing: 14

        Item {
            id: iconBox
            visible: root.icon !== ""
            width: visible ? 40 : 0
            height: 40
            IconImage {
                anchors.fill: parent
                source: root.icon
                asynchronous: true
            }
        }

        Column {
            id: col
            width: row.width - iconBox.width - (iconBox.visible ? row.spacing : 0)
            spacing: 6

            Item {
                width: parent.width
                height: 18
                Label {
                    width: parent.width - closeBtn.width - 4
                    text: (root.notif ? root.notif.appName || "" : "")
                    size: Theme.fontSmall
                    dim: true
                    bold: true
                    font.letterSpacing: 0.8
                }
                IconButton {
                    id: closeBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    size: 20; iconSize: 11
                    icon: "󰅖"
                    opacity: area.containsMouse || containsMouse ? 1 : 0
                    onClicked: root.notif.dismiss()
                }
            }
            Label {
                width: parent.width
                text: root.notif ? root.notif.summary : ""
                bold: true
                size: Theme.fontLarge - 1
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                color: root.critical ? Theme.love : Theme.fg
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: root.notif ? root.notif.body : ""
                textFormat: Text.StyledText
                linkColor: Theme.iris
                onLinkActivated: l => Qt.openUrlExternally(l)
                muted: true
                size: Theme.fontSize
                wrapMode: Text.WordWrap
                maximumLineCount: root.popup ? 6 : 8
            }
            Row {
                visible: root.buttons.length > 0
                spacing: 6
                topPadding: 4
                Repeater {
                    model: root.buttons
                    delegate: MouseArea {
                        id: btn
                        required property var modelData
                        width: bt.implicitWidth + 24; height: 30
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { modelData.invoke(); }
                        Rectangle { anchors.fill: parent; radius: Theme.radiusSmall; color: btn.containsMouse ? Theme.pressed : Theme.hover }
                        Label { id: bt; anchors.centerIn: parent; text: btn.modelData.text }
                    }
                }
            }
        }
    }
}
