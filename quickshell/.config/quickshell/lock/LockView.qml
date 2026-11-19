import QtQuick
import qs.services
import qs.components

// What the lock shows on each screen: the clock, the password field, and the brief in a few lines.
Item {
    id: view
    required property var shell

    property date now: new Date()

    // The password field keeps the keyboard. After a lid close and resume it once had to be clicked first
    // (2026-11-19): take it back whenever this screen's window becomes active again, the field is usable
    // again, or (checked every second) the window has the keyboard but the field doesn't. The changes go
    // to the lock's log, to see next time whether the compositor gave the window the keyboard at all.
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: {
        console.info("agentic-lock: window " + (windowActive ? "has" : "lost") + " the keyboard");
        if (windowActive) input.forceActiveFocus();
    }
    Timer {
        interval: 1000; repeat: true
        running: view.windowActive && !input.activeFocus && input.enabled
        onTriggered: { console.info("agentic-lock: field had no focus, taking it back"); input.forceActiveFocus(); }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: view.now = new Date() }

    Column {
        anchors.centerIn: parent
        spacing: 18
        width: Math.min(parent.width - 48, 420)

        Label {
            visible: view.shell.trial > 0 && !view.shell.done
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Trial: unlocks by itself in " + view.shell.left + " s"
            color: Theme.gold
            size: Theme.fontSmall
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatTime(view.now, "HH:mm")
            size: Math.round(Math.min(view.height / 5, 96))
            bold: true
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(view.now, "dddd, d MMMM")
            muted: true
            size: Theme.fontLarge
        }

        Item { width: 1; height: 8 }

        Rectangle {
            width: parent.width
            height: 44
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: view.shell.failed ? Theme.love : (input.activeFocus ? Theme.borderStrong : Theme.border)

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontLarge
                focus: true
                enabled: !view.shell.checking && !view.shell.done
                text: view.shell.buffer
                onTextChanged: if (view.shell.buffer !== text) view.shell.buffer = text
                Keys.onReturnPressed: view.shell.submit()
                Keys.onEnterPressed: view.shell.submit()
                Keys.onEscapePressed: view.shell.buffer = ""
                Component.onCompleted: forceActiveFocus()
                onEnabledChanged: if (enabled) forceActiveFocus()
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 14
                visible: input.text === ""
                text: "Password"
                dim: true
                size: Theme.fontLarge
            }
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: view.shell.status
            color: view.shell.failed ? Theme.love : Theme.fgMuted
            size: Theme.fontSmall
        }

        Item { width: 1; height: 8 }

        Column {
            width: parent.width
            spacing: 4
            visible: view.shell.brief.length > 0
            Repeater {
                model: view.shell.brief
                Label {
                    required property string modelData
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    muted: true
                    size: Theme.fontSmall
                }
            }
        }
    }
}
