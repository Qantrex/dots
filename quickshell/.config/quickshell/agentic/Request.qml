import QtQuick
import qs.services
import qs.components

// One thing that waits for me, as a card: a tool call that needs a yes or a no, or questions
// with their options (a question dialog of a session, or a thread's question round).
//
// The session's own terminal asks the same at the same time and the first answer counts, so
// leaving a card alone is always fine. Everything shown comes from the session and is plain
// text. Nothing here reacts to Enter: a yes takes a click, and only once the whole request
// was in view.
Rectangle {
    id: card

    required property var request
    property bool showSource: false           // on the home tab: say who asks

    readonly property bool isAsk: request.kind === "ask"
    readonly property var questions: isAsk ? (request.questions || []) : []
    readonly property bool busy: Agentic.answering === request.id
    property bool sawEnd: false               // the end of a long request was scrolled into view
    readonly property bool readAll: !what.visible || !what.cut || sawEnd
    property var picked: ({})                 // question -> the chosen labels
    property var typed: ({})                  // question -> the free text
    signal cleared(string question)

    function answerOf(q) {
        const labels = picked[q.question] || [];
        const text = (typed[q.question] || "").trim();
        if (q.multiSelect === true) return labels.concat(text ? [text] : []);
        return text || labels[0] || "";
    }
    readonly property bool complete: questions.length > 0 && questions.every(q => answerOf(q).length > 0)

    function pick(q, label) {
        const p = Object.assign({}, picked);
        const had = p[q.question] || [];
        if (q.multiSelect === true) {
            p[q.question] = had.indexOf(label) >= 0 ? had.filter(l => l !== label) : had.concat([label]);
        } else {
            p[q.question] = had[0] === label ? [] : [label];
            if (typed[q.question]) {
                const t = Object.assign({}, typed);
                t[q.question] = "";
                typed = t;
                cleared(q.question);
            }
        }
        picked = p;
    }
    function type(q, text) {
        const t = Object.assign({}, typed);
        t[q.question] = text;
        typed = t;
        // One answer only: what is typed replaces the chosen option.
        if (q.multiSelect !== true && text.trim() !== "" && (picked[q.question] || []).length > 0) {
            const p = Object.assign({}, picked);
            p[q.question] = [];
            picked = p;
        }
    }
    function submit() {
        if (!complete || busy) return;
        const answers = {};
        for (const q of questions) answers[q.question] = answerOf(q);
        Agentic.answer(request.id, request.tab, "allow", { answers: answers });
    }

    component Btn: MouseArea {
        id: btn
        property string text: ""
        property bool strong: false
        implicitWidth: btnLabel.implicitWidth + 24
        implicitHeight: btnLabel.implicitHeight + 12
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        opacity: enabled ? 1 : 0.35
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: btn.strong ? (btn.containsMouse ? Theme.fillHover : Theme.accent)
                              : (btn.pressed ? Theme.pressed : (btn.containsMouse ? Theme.hover : "transparent"))
            border.width: btn.strong ? 0 : 1
            border.color: Theme.border
        }
        Label {
            id: btnLabel
            anchors.centerIn: parent
            text: btn.text
            size: Agentic.fontSmall
            bold: btn.strong
            color: btn.strong ? Theme.inverse : Theme.fg
        }
    }

    implicitHeight: body.implicitHeight + 24
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Theme.gold
    opacity: busy ? 0.6 : 1

    Column {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8

        Item {
            width: parent.width
            implicitHeight: when.implicitHeight
            Label {
                anchors { left: parent.left; right: when.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: ((card.showSource && card.request.name ? card.request.name + "  /  " : "") + (card.request.tool || "")).toUpperCase()
                size: 10
                dim: true
                bold: true
                font.letterSpacing: 1.2
            }
            Label {
                id: when
                anchors { right: parent.right; top: parent.top }
                text: card.request.at || ""
                dim: true
                size: Agentic.fontSmall
            }
        }

        Label {
            width: parent.width
            text: card.request.title || ""
            size: Agentic.fontSize
            color: Theme.gold
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            verticalAlignment: Text.AlignTop
        }

        // A tool call: all of what it would do.
        Flickable {
            id: what
            visible: !card.isAsk && (card.request.text || "") !== ""
            width: parent.width
            height: Math.min(shown.contentHeight, 12 * Math.ceil(Agentic.fontSize * 1.45))
            contentHeight: shown.contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            readonly property bool cut: contentHeight > height + 1
            // Only a scroll moves contentY, so a card that is still being laid out cannot count as read.
            onContentYChanged: if (cut && contentY > 0 && contentY + height >= contentHeight - 2) card.sawEnd = true

            Rectangle {
                visible: what.cut
                x: what.width - 3
                y: what.contentY + what.visibleArea.yPosition * what.height
                width: 3
                height: what.visibleArea.heightRatio * what.height
                radius: 1.5
                color: Theme.fgMuted
            }
            TextEdit {
                id: shown
                width: what.width - 10
                text: card.request.text || ""
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
        }
        Label {
            visible: !card.isAsk && card.request.cut === true
            width: parent.width
            text: "Too long to show here in full. Read and answer it in the terminal."
            size: Agentic.fontSmall
            color: Theme.gold
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Label {
            visible: what.visible && what.cut && !card.readAll && card.request.cut !== true
            width: parent.width
            text: "There is more below. Scroll to the end before you allow it."
            size: Agentic.fontSmall
            color: Theme.gold
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Label {
            visible: !card.isAsk && (card.request.cwd || "") !== ""
            width: parent.width
            text: "in " + (card.request.cwd || "")
            size: Agentic.fontSmall
            dim: true
            elide: Text.ElideMiddle
        }

        // Questions: the options as rows, and a line for an answer of my own.
        Repeater {
            model: card.questions
            Column {
                id: ask
                required property var modelData
                width: body.width
                spacing: 4

                Label {
                    visible: text !== ""
                    text: (ask.modelData.header || "").toUpperCase() + (ask.modelData.multiSelect === true ? "  /  SEVERAL POSSIBLE" : "")
                    size: 10
                    dim: true
                    bold: true
                    font.letterSpacing: 1.2
                }
                Label {
                    width: parent.width
                    bottomPadding: 2
                    text: ask.modelData.question || ""
                    size: Agentic.fontSize
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    verticalAlignment: Text.AlignTop
                }
                Repeater {
                    model: ask.modelData.options || []
                    MouseArea {
                        id: opt
                        required property var modelData
                        readonly property bool on: (card.picked[ask.modelData.question] || []).indexOf(modelData.label) >= 0
                        width: ask.width
                        height: optText.implicitHeight + 12
                        enabled: !card.busy
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.pick(ask.modelData, modelData.label)

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: opt.on ? Theme.selected : (opt.containsMouse ? Theme.hover : "transparent")
                            border.width: 1
                            border.color: opt.on ? Theme.fg : Theme.border
                        }
                        Column {
                            id: optText
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6; leftMargin: 10; rightMargin: 10 }
                            spacing: 1
                            Label {
                                width: parent.width
                                text: opt.modelData.label || ""
                                size: Agentic.fontSize
                                bold: opt.on
                                wrapMode: Text.Wrap
                                elide: Text.ElideNone
                                verticalAlignment: Text.AlignTop
                            }
                            Label {
                                visible: text !== ""
                                width: parent.width
                                text: opt.modelData.description || ""
                                size: Agentic.fontSmall
                                muted: true
                                wrapMode: Text.Wrap
                                elide: Text.ElideNone
                                verticalAlignment: Text.AlignTop
                            }
                        }
                    }
                }
                Rectangle {
                    width: ask.width
                    height: other.implicitHeight + 12
                    radius: Theme.radiusSmall
                    color: "transparent"
                    border.width: 1
                    border.color: other.activeFocus ? Theme.borderStrong : (other.text.trim() !== "" ? Theme.fg : Theme.border)

                    TextInput {
                        id: other
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                        clip: true
                        readOnly: card.busy
                        selectByMouse: true
                        color: Theme.fg
                        selectionColor: Theme.pressed
                        selectedTextColor: Theme.fg
                        font.family: Theme.font
                        font.pointSize: Agentic.fontPt
                        onTextEdited: card.type(ask.modelData, text)
                        // Enter does nothing here: an answer goes out with the button.
                        Keys.onPressed: e => {
                            if (Agentic.key(e)) return;
                            if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                                e.accepted = true;
                        }
                        Label {
                            visible: other.text === "" && other.preeditText === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Something else"
                            dim: true
                            size: Agentic.fontSize
                        }
                    }
                    Connections {
                        target: card
                        function onCleared(question) { if (question === ask.modelData.question) other.text = ""; }
                    }
                }
                Item { width: 1; height: 2 }
            }
        }

        Label {
            visible: card.request.tool === "thread ask"
            width: parent.width
            text: "The main chat may ask you the same. The first answer counts."
            size: Agentic.fontSmall
            dim: true
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }

        Row {
            spacing: 8
            Btn {
                visible: !card.isAsk && card.request.cut !== true
                text: "Allow"
                strong: true
                enabled: !card.busy && card.readAll
                onClicked: Agentic.answer(card.request.id, card.request.tab, "allow", {})
            }
            Btn {
                visible: !card.isAsk
                text: "Deny"
                enabled: !card.busy
                onClicked: Agentic.answer(card.request.id, card.request.tab, "deny", {})
            }
            Btn {
                visible: card.isAsk
                text: card.questions.length > 1 ? "Send answers" : "Send answer"
                strong: card.complete
                enabled: card.complete && !card.busy
                onClicked: card.submit()
            }
            Btn {
                visible: (card.request.tab || "") !== ""
                text: "In the terminal"
                onClicked: Agentic.terminal(card.request.tab)
            }
        }
    }
}
