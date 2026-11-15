import QtQuick
import qs.services

// A slider with an icon button on the left (e.g. mute) and the value on the right.
Item {
    id: root
    property real value: 0               // 0..1
    property string icon: ""
    property bool off: false             // muted: the fill turns grey
    property string valueText: Math.round(value * 100) + "%"
    signal moved(real v)
    signal iconClicked()

    implicitHeight: 32
    implicitWidth: 280

    MouseArea {
        id: iconBtn
        width: 30; height: 30
        anchors.verticalCenter: parent.verticalCenter
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.iconClicked()
        Rectangle { anchors.fill: parent; radius: Theme.radiusSmall; color: iconBtn.containsMouse ? Theme.hover : "transparent" }
        Glyph { anchors.centerIn: parent; text: root.icon; color: root.off ? Theme.fgDim : Theme.fg }
    }

    Item {
        id: trackArea
        anchors { left: iconBtn.right; leftMargin: 8; right: valueLabel.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        height: 20

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: Theme.track
            Rectangle {
                width: Math.max(height, parent.width * Math.min(1, root.value))
                height: parent.height; radius: 3
                color: root.off ? Theme.fgDim : Theme.fg
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.animFast } }
            }
        }
        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.width * Math.min(1, root.value) - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: root.off ? Theme.fgMuted : Theme.fg
            scale: drag.pressed || drag.containsMouse ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: Theme.animFast } }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function apply(x) { root.moved(Math.max(0, Math.min(1, (x - 6) / trackArea.width))); }
            onPressed: m => apply(m.x)
            onPositionChanged: m => { if (pressed) apply(m.x); }
            onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    Label {
        id: valueLabel
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 40
        horizontalAlignment: Text.AlignRight
        text: root.valueText
        muted: true
        size: Theme.fontSmall
    }
}
