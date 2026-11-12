import QtQuick
import qs.services

// One of the bar's floating, translucent pills.
Rectangle {
    default property alias content: row.data
    property alias spacing: row.spacing
    property int padding: 4

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.radius
    color: Theme.bg
    border.width: 1
    border.color: Theme.border
    visible: implicitWidth > padding * 2 + 1

    Behavior on implicitWidth { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: parent.padding
        spacing: 2
    }
}
