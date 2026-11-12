import QtQuick
import qs.services

// A round icon button (media controls, dismiss, ...).
MouseArea {
    id: root
    property string icon: ""
    property real size: 30
    property real iconSize: Theme.iconSize
    property bool filled: false
    property color iconColor: filled ? Theme.inverse : Theme.fg
    implicitWidth: size
    implicitHeight: size
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.filled ? (root.containsMouse ? Qt.rgba(1, 1, 1, 0.85) : Theme.fg)
                           : (root.pressed ? Theme.pressed : (root.containsMouse ? Theme.hover : "transparent"))
    }
    Glyph { anchors.centerIn: parent; text: root.icon; size: root.iconSize; color: root.iconColor }
}
