import QtQuick
import qs.services

// A row in a popout list: icon, title, subtitle, a value on the right.
MouseArea {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string value: ""
    property color valueColor: Theme.fgMuted
    property bool highlighted: false     // e.g. the connected network
    property bool clickable: true
    property color titleColor: Theme.fg

    implicitHeight: subtitle !== "" ? 42 : 32
    implicitWidth: 300
    hoverEnabled: clickable
    cursorShape: clickable ? Qt.PointingHandCursor : Qt.ArrowCursor

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.highlighted ? Qt.rgba(1, 1, 1, 0.08) : (root.containsMouse ? Theme.hover : "transparent")
    }

    Glyph {
        id: ic
        visible: root.icon !== ""
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        width: visible ? 20 : 0
        text: root.icon
        color: root.highlighted ? Theme.fg : Theme.fgMuted
    }
    Column {
        anchors { left: ic.right; leftMargin: root.icon !== "" ? 10 : 2; right: val.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        Label { width: parent.width; text: root.title; bold: root.highlighted; color: root.titleColor }
        Label { width: parent.width; text: root.subtitle; visible: text !== ""; size: Theme.fontSmall; muted: true }
    }
    Label {
        id: val
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        text: root.value
        color: root.valueColor
        size: Theme.fontSmall
        elide: Text.ElideNone
    }
}
