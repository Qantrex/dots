import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// One conversation of the agent panel: the main chat or a thread, read from the transcript
// Claude Code writes (`agentic-shell feed`), with an input box that sends through `thread send`.
// Panel.qml makes one of these per tab and drops it on a tab change, which ends its feed.
Item {
    id: chat

    required property string target
    property bool ready: false        // the history is through
    property bool gone: false         // no Claude session in that window right now
    property bool stick: true         // follow new lines; off while scrolled up
    property string problem: ""       // why the last send did not go out

    function takeFocus() { input.forceActiveFocus(); }

    function apply(op) {
        if (op.op === "reset") {
            lines.clear();
            ready = false; gone = false; stick = true;
        } else if (op.op === "add" || op.op === "set") {
            const e = { eid: op.id || "", kind: op.role || "note", body: op.text || "", rich: op.rich || "", at: op.at || "" };
            if (op.op === "set") {
                for (let i = lines.count - 1; i >= 0; i--) {
                    if (lines.get(i).eid === e.eid) { lines.set(i, e); return; }
                }
            }
            lines.append(e);
        } else if (op.op === "ready") {
            ready = true;
            view.follow();
        } else if (op.op === "gone") {
            lines.clear();
            gone = true; ready = true;
        }
    }

    function submit() {
        if (Agentic.sending || !input.text.trim()) return;
        problem = "";
        Agentic.send(target, input.text);
    }

    Component.onCompleted: input.text = Agentic.drafts[target] || ""
    Component.onDestruction: Agentic.drafts[target] = input.text

    Connections {
        target: Agentic
        function onSent(to) {
            if (to !== chat.target) return;
            input.text = "";
            chat.stick = true;
            view.follow();
        }
        function onSendFailed(to, why) { if (to === chat.target) chat.problem = why; }
    }

    ListModel { id: lines }

    // Runs only while the panel is open: closing it or leaving the tab ends the process.
    Process {
        id: feed
        running: Agentic.open
        command: [Agentic.bin + "/agentic-shell", "feed", chat.target, "--strong", "" + Theme.fg, "--code", "" + Theme.fgMuted]
        stdout: SplitParser {
            onRead: line => {
                try { chat.apply(JSON.parse(line)); } catch (e) {}
            }
        }
    }

    Flickable {
        id: view
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: foot.top }
        contentHeight: col.implicitHeight + 2 * Theme.pad
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        property bool auto: false
        function follow() {
            if (!chat.stick) return;
            auto = true;
            contentY = Math.max(0, contentHeight - height);
            auto = false;
        }
        onContentHeightChanged: follow()
        onHeightChanged: follow()
        onContentYChanged: if (!auto) chat.stick = contentHeight - height - contentY < 32

        Column {
            id: col
            x: Theme.pad
            y: Theme.pad
            width: view.width - 2 * Theme.pad
            spacing: 10

            Repeater {
                model: lines
                Loader {
                    id: entry
                    required property int index
                    required property string kind
                    required property string body
                    required property string rich
                    required property string at
                    width: col.width
                    sourceComponent: kind === "user" ? userLine : (kind === "assistant" ? assistantLine
                                   : (kind === "tool" ? toolLine : (kind === "ask" ? askLine : noteLine)))

                    Component {
                        id: userLine
                        Rectangle {
                            implicitHeight: mine.implicitHeight + 16
                            radius: Theme.radius
                            color: Theme.surface
                            TextEdit {
                                id: mine
                                anchors { left: parent.left; right: when.left; top: parent.top; margins: 8; leftMargin: 10 }
                                text: entry.body
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                                textFormat: TextEdit.PlainText
                                color: Theme.fg
                                selectionColor: Theme.pressed
                                selectedTextColor: Theme.fg
                                font.family: Theme.font
                                font.pointSize: Agentic.fontPt
                            }
                            Label {
                                id: when
                                anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 9 }
                                text: entry.at
                                dim: true
                                size: Agentic.fontSmall
                            }
                        }
                    }
                    Component {
                        id: assistantLine
                        TextEdit {
                            leftPadding: 2
                            text: entry.rich !== "" ? entry.rich : entry.body
                            textFormat: entry.rich !== "" ? TextEdit.RichText : TextEdit.PlainText
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            color: Theme.fg
                            selectionColor: Theme.pressed
                            selectedTextColor: Theme.fg
                            font.family: Theme.font
                            font.pointSize: Agentic.fontPt
                        }
                    }
                    Component {
                        id: toolLine
                        Label {
                            leftPadding: 2
                            text: entry.body
                            dim: true
                            size: Agentic.fontSmall
                            maximumLineCount: 1
                        }
                    }
                    Component {
                        id: noteLine
                        Label {
                            leftPadding: 2
                            text: entry.body
                            dim: true
                            size: Agentic.fontSmall
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            verticalAlignment: Text.AlignTop
                        }
                    }
                    // A question Claude asked with its own dialog: answered in the terminal.
                    Component {
                        id: askLine
                        Column {
                            spacing: 6
                            Label {
                                width: parent.width
                                leftPadding: 2
                                text: entry.body
                                size: Agentic.fontSize
                                color: Theme.gold
                                wrapMode: Text.Wrap
                                elide: Text.ElideNone
                                verticalAlignment: Text.AlignTop
                            }
                            MouseArea {
                                visible: entry.index === lines.count - 1 && waiting.count === 0
                                width: answer.implicitWidth + 20; height: answer.implicitHeight + 10
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Agentic.terminal()
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusSmall
                                    color: parent.containsMouse ? Theme.hover : "transparent"
                                    border.width: 1
                                    border.color: Theme.gold
                                }
                                Label { id: answer; anchors.centerIn: parent; text: "Answer in the terminal"; color: Theme.gold; size: Agentic.fontSmall }
                            }
                        }
                    }
                }
            }
        }
    }

    Label {
        visible: lines.count === 0
        anchors.centerIn: view
        width: view.width - 4 * Theme.pad
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        dim: true
        size: Agentic.fontSize
        text: chat.gone ? "No Claude session is running in '" + chat.target + "' right now."
                        : (chat.ready ? "Nothing here yet." : "Reading the conversation ...")
    }

    // Back to the newest line.
    IconButton {
        visible: !chat.stick
        anchors { right: view.right; rightMargin: Theme.pad; bottom: view.bottom; bottomMargin: 8 }
        icon: "󰁅"
        filled: true
        onClicked: { chat.stick = true; view.follow(); }
    }

    Item {
        id: foot
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.pad }
        height: asks.height + status.height + box.height

        // What waits for a yes, a no or an answer in this conversation.
        Flickable {
            id: asks
            anchors { left: parent.left; right: parent.right; top: parent.top }
            // As much room as it needs; the conversation above keeps a few lines.
            height: Math.min(cards.implicitHeight, Math.max(120, chat.height - box.height - status.height - 96))
            contentHeight: cards.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: cards
                width: asks.width
                spacing: 8
                bottomPadding: waiting.count > 0 ? 8 : 0
                Repeater {
                    id: waiting
                    model: ScriptModel { values: Agentic.requestsOf(chat.target); objectProp: "id" }
                    Request {
                        required property var modelData
                        request: modelData
                        width: cards.width
                    }
                }
            }
        }

        Rectangle {
            visible: asks.contentHeight > asks.height + 1
            x: asks.width + 4
            y: asks.y + asks.visibleArea.yPosition * asks.height
            width: 3
            height: asks.visibleArea.heightRatio * asks.height
            radius: 1.5
            color: Theme.fgMuted
        }

        // What the thread is doing, or why a message or an answer did not go out.
        Item {
            id: status
            readonly property string state: chat.target === "main" ? "" : Agentic.stateOf(chat.target)
            readonly property string refused: Agentic.answerTab === chat.target ? Agentic.answerProblem : ""
            readonly property string line: chat.problem !== "" ? chat.problem : refused !== "" ? refused
                : (Agentic.sending ? "Sending ..." : (state !== "" ? state + (Agentic.detailOf(chat.target) ? ": " + Agentic.detailOf(chat.target) : "") : ""))
            anchors { left: parent.left; right: parent.right; top: asks.bottom }
            height: line !== "" ? Math.max(told.implicitHeight, 22) + 6 : 0
            visible: line !== ""

            Label {
                id: told
                anchors { left: parent.left; leftMargin: 4; right: toTerm.visible ? toTerm.left : parent.right; rightMargin: 8; top: parent.top }
                text: status.line
                size: Agentic.fontSmall
                wrapMode: Text.Wrap
                maximumLineCount: 3
                verticalAlignment: Text.AlignTop
                color: chat.problem !== "" || status.refused !== "" ? Theme.love : (status.state === "needs you" ? Theme.gold : Theme.fgDim)
            }
            MouseArea {
                id: toTerm
                visible: chat.problem !== ""
                anchors { right: parent.right; top: parent.top }
                width: toTermLabel.implicitWidth + 12; height: toTermLabel.implicitHeight + 2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Agentic.terminal()
                Label { id: toTermLabel; anchors.centerIn: parent; text: "Open terminal"; size: Agentic.fontSmall; color: toTerm.containsMouse ? Theme.fg : Theme.fgMuted }
            }
        }

        Rectangle {
            id: box
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.min(input.contentHeight, 5 * lineHeight) + 20
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: input.activeFocus ? Theme.borderStrong : Theme.border

            readonly property real lineHeight: Math.ceil(Agentic.fontSize * 1.45)

            Flickable {
                id: typed
                anchors { left: parent.left; right: go.left; top: parent.top; bottom: parent.bottom; margins: 10; leftMargin: 12; rightMargin: 6 }
                contentHeight: input.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: input
                    width: typed.width
                    height: Math.max(typed.height, contentHeight)
                    focus: true
                    readOnly: Agentic.sending
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    color: Theme.fg
                    selectionColor: Theme.pressed
                    selectedTextColor: Theme.fg
                    font.family: Theme.font
                    font.pointSize: Agentic.fontPt

                    onCursorRectangleChanged: {
                        const r = cursorRectangle;
                        if (r.y < typed.contentY) typed.contentY = r.y;
                        else if (r.y + r.height > typed.contentY + typed.height) typed.contentY = r.y + r.height - typed.height;
                    }
                    onTextChanged: if (chat.problem !== "") chat.problem = ""

                    Keys.onPressed: e => {
                        if (Agentic.key(e)) return;
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            if (e.modifiers & Qt.ShiftModifier) return;    // a new line
                            chat.submit();
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                            e.accepted = true;
                        }
                    }

                    Label {
                        visible: input.text === "" && input.preeditText === ""
                        text: chat.gone ? "No session to write to" : "Message " + chat.target
                        dim: true
                        size: Agentic.fontSize
                    }
                }
            }
            IconButton {
                id: go
                anchors { right: parent.right; rightMargin: 6; bottom: parent.bottom; bottomMargin: 5 }
                icon: "󰒊"
                filled: input.text.trim() !== "" && !Agentic.sending
                opacity: input.text.trim() !== "" ? 1 : 0.4
                onClicked: chat.submit()
            }
        }
    }
}
