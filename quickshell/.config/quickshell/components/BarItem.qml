import QtQuick
import qs.services

// A clickable spot in the bar: hover highlight, left/middle/right click, scroll.
MouseArea {
    id: root
    default property alias content: row.data
    property alias spacing: row.spacing
    property int hpad: 8
    property bool active: false          // its popout is open
    property string tip: ""

    signal leftClicked()
    signal middleClicked()
    signal rightClicked()
    signal scrolled(int dir)             // +1 up, -1 down

    implicitWidth: row.implicitWidth + hpad * 2
    implicitHeight: Theme.barHeight - 8
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onClicked: m => {
        if (m.button === Qt.LeftButton) leftClicked();
        else if (m.button === Qt.MiddleButton) middleClicked();
        else rightClicked();
    }
    onWheel: w => scrolled(w.angleDelta.y > 0 ? 1 : -1)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.active ? Theme.pressed : (root.containsMouse ? Theme.hover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}
