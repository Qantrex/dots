import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import qs.components

// The tray: left click = activate, right click = its menu, middle = secondary.
Column {
    id: root
    required property var bar
    width: 240
    spacing: 2

    Repeater {
        model: SystemTray.items.values
        delegate: MouseArea {
            id: entry
            required property var modelData
            width: root.width
            height: 34
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: m => {
                if (m.button === Qt.MiddleButton) modelData.secondaryActivate();
                else if (m.button === Qt.RightButton || modelData.onlyMenu) {
                    if (modelData.hasMenu) {
                        const p = entry.mapToItem(null, 0, entry.height);
                        modelData.display(QsWindow.window, p.x, p.y);
                    }
                } else {
                    modelData.activate();
                    Shell.close();
                }
            }

            Rectangle { anchors.fill: parent; radius: Theme.radiusSmall; color: entry.containsMouse ? Theme.hover : "transparent" }
            Row {
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 10
                AppIcon { anchors.verticalCenter: parent.verticalCenter; source: entry.modelData.icon; size: 18 }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.width - 50
                    text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                }
            }
        }
    }
}
