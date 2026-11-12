import QtQuick
import qs.services

// A small all-caps header inside a popout, with an optional action on the right.
Item {
    id: root
    property string text: ""
    property string action: ""
    signal actionClicked()
    implicitHeight: 24
    implicitWidth: 200

    Label {
        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
        text: root.text.toUpperCase()
        size: 10
        dim: true
        bold: true
        font.letterSpacing: 1.2
    }
    MouseArea {
        id: act
        visible: root.action !== ""
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: actLabel.implicitWidth + 12; height: 20
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.actionClicked()
        Label { id: actLabel; anchors.centerIn: parent; text: root.action; size: Theme.fontSmall; color: act.containsMouse ? Theme.fg : Theme.fgMuted }
    }
}
