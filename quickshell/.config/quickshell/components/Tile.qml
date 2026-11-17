import QtQuick
import qs.services

// A control-centre toggle: icon, title, state line. White fill when on.
// The chevron (if `expandable`) opens a detail list instead of toggling.
Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool on: false
    property bool expandable: false
    property bool expanded: false
    property color accent: "transparent"   // gold/love border for warnings
    signal toggled()
    signal expand()

    implicitHeight: 54
    radius: Theme.radiusSmall
    color: on ? Theme.accent : (main.containsMouse ? Theme.hover : Theme.surface)
    border.width: 1
    border.color: accent.a > 0 ? accent : (on ? Theme.accent : Theme.border)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    MouseArea {
        id: main
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: root.expandable ? chevron.left : parent.right }
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Row {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: root.expandable ? chevron.left : parent.right; rightMargin: 6 }
        spacing: 10
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: 17
            color: root.on ? Theme.inverse : Theme.fg
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 30
            Label { width: parent.width; text: root.title; bold: true; color: root.on ? Theme.inverse : Theme.fg }
            Label {
                width: parent.width
                text: root.subtitle
                visible: text !== ""
                size: Theme.fontSmall
                color: root.on ? Theme.inverseMuted : Theme.fgMuted
            }
        }
    }

    MouseArea {
        id: chevron
        visible: root.expandable
        width: visible ? 30 : 0
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expand()
        Rectangle {
            anchors { fill: parent; margins: 4 }
            radius: Theme.radiusSmall - 2
            color: chevron.containsMouse ? (root.on ? Theme.inverseHover : Theme.hover) : "transparent"
        }
        Glyph {
            anchors.centerIn: parent
            text: root.expanded ? "󰅀" : "󰅂"
            size: 14
            color: root.on ? Theme.inverse : Theme.fgMuted
        }
    }
}
