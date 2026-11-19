import QtQuick
import qs.services
import qs.components

// One tab of the agent panel: the main chat, a thread (with a mark for what it is doing) or
// the home tab (with the number of new inbox events).
MouseArea {
    id: root
    property string name: ""
    readonly property bool current: Agentic.target === name
    readonly property bool isHome: name === "home"
    readonly property string state: isHome || name === "main" ? "" : Agentic.stateOf(name)
    readonly property bool needsMe: state === "needs you"

    implicitWidth: row.implicitWidth + 20
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Agentic.target = name

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.current ? Theme.selected : (root.containsMouse ? Theme.hover : "transparent")
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Glyph {
            visible: root.isHome
            anchors.verticalCenter: parent.verticalCenter
            text: "󰋜"
            size: 14
            color: root.current ? Theme.fg : Theme.fgMuted
        }
        // A thread: gold when it waits for me, a quiet dot while it works.
        Rectangle {
            visible: root.state === "working" || root.needsMe
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6; radius: 3
            color: root.needsMe ? Theme.gold : Theme.fgDim
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.name
            size: Agentic.fontSize
            color: root.needsMe ? Theme.gold : (root.current ? Theme.fg : Theme.fgMuted)
            bold: root.current
        }
        Rectangle {
            visible: root.isHome && Agentic.newCount > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(16, count.implicitWidth + 8); height: 16; radius: 8
            color: Theme.accent
            Label { id: count; anchors.centerIn: parent; text: String(Agentic.newCount); size: 10; bold: true; color: Theme.inverse }
        }
    }
}
