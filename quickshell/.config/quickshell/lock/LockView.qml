import QtQuick
import qs.services
import qs.components

// What the lock shows on each screen: the theme's picture (the ASCII "Creation of Adam" in root), the clock in
// the black above the hands, the password typed into the gap between the fingertips, and under the hands
// what PAM says and the brief. The same layout as hyprlock (theme/templates/hyprlock.conf), which stays the
// fallback; without a picture the same places on a black screen.
Item {
    id: view
    required property var shell

    property date now: new Date()

    // The password field keeps the keyboard. Two things can go: the window's keyboard (Window.active, what the
    // compositor gives) and the field's focus inside the window. On the lid close of 2026-11-19 23:23 the
    // window went inactive as the suspend began and never became active again, yet a click on the field
    // made typing work; so the field takes its focus back whatever the window says, and the log records
    // both, every click and the first typing after a loss, to tell which of the two was missing.
    readonly property bool windowActive: Window.active
    readonly property bool fieldFocus: input.activeFocus
    readonly property string focusItem: Window.activeFocusItem ? String(Window.activeFocusItem).split("(")[0] : "none"
    property bool lostSince: false
    function focusState() { return "window active: " + view.windowActive + ", field focus: " + view.fieldFocus; }
    onWindowActiveChanged: {
        console.info("agentic-lock: window " + (windowActive ? "has" : "lost") + " the keyboard (" + focusState() + ")");
        view.shell.keyboardViews += windowActive ? 1 : -1;   // shell.qml asks Hyprland when no screen has it
        if (!windowActive) view.lostSince = true;
        if (input.enabled) input.forceActiveFocus();
    }
    onFieldFocusChanged: console.info("agentic-lock: field " + (fieldFocus ? "has" : "lost") + " its focus (" + focusState() + ")")
    Component.onDestruction: if (windowActive) view.shell.keyboardViews -= 1
    Timer {
        interval: 1000; repeat: true
        running: !input.activeFocus && input.enabled
        onTriggered: { console.info("agentic-lock: field had no focus, taking it back (" + view.focusState() + ")"); input.forceActiveFocus(); }
    }
    // shell.qml's tries while no screen has the keyboard: log the state, and from the third try on also ask
    // Qt to activate the window (the real lock only: in the preview it would take focus from the desktop).
    Connections {
        target: view.shell
        function onFocusTry(n) {
            console.info("agentic-lock: try " + n + " (" + view.focusState() + ")");
            if (n >= 3 && !view.shell.preview && !view.windowActive && view.Window.window) view.Window.window.requestActivate();
        }
    }
    PointHandler {
        onActiveChanged: if (active) console.info("agentic-lock: pointer press (" + view.focusState() + ")")
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: view.now = new Date() }

    // The picture, cropped to the screen and dimmed like hyprlock's (brightness 0.55).
    Image {
        id: wall
        anchors.fill: parent
        source: Theme.wallpaper !== "" ? "file://" + Theme.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: status === Image.Ready
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45; visible: wall.visible }

    // Where a point of the picture lands on this screen (fractions of the picture; measured on the root
    // wallpaper: fingertip gap at 0.483, 0.531, hands from 0.34 to 0.71 of its height). No picture: the
    // screen itself.
    readonly property real iw: wall.visible ? wall.implicitWidth : width
    readonly property real ih: wall.visible ? wall.implicitHeight : height
    readonly property real sc: Math.max(width / iw, height / ih)
    function px(f) { return (width - iw * sc) / 2 + f * iw * sc; }
    function py(f) { return (height - ih * sc) / 2 + f * ih * sc; }

    // The clock and the date, in the black above the hands.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(24, view.py(0.31) - height)
        width: Math.min(parent.width - 48, 520)
        spacing: 10

        Label {
            visible: view.shell.trial > 0 && !view.shell.done
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            // A fixed time, not a countdown: a countdown repaints every second, and a real lock only once a
            // minute, so a trial would hide what goes wrong between frames (the keyboard focus, 2026-11-19).
            text: "Trial: unlocks by itself at " + view.shell.trialEnd
            color: Theme.gold
            size: Theme.fontSmall
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatTime(view.now, "HH:mm")
            size: Math.round(Math.min(view.height / 6, 96))
            bold: true
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(view.now, "dddd, d MMMM")
            muted: true
            size: Theme.fontLarge
        }
    }

    // The password: no box, only the dots, centred in the gap between the fingertips.
    TextInput {
        id: input
        width: Math.min(260, view.width - 48)
        height: 40
        x: view.px(0.483) - width / 2
        y: view.py(0.531) - height / 2
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        passwordCharacter: "●"
        cursorVisible: false
        cursorDelegate: Item {}
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontLarge
        font.letterSpacing: 4
        clip: true
        focus: true
        enabled: !view.shell.checking && !view.shell.done
        text: view.shell.buffer
        onTextChanged: {
            if (view.shell.buffer !== text) view.shell.buffer = text;
            if (view.lostSince && text.length > 0) {
                view.lostSince = false;
                console.info("agentic-lock: typing reached the field after a loss (" + view.focusState() + ")");
            }
        }
        Keys.onReturnPressed: view.shell.submit()
        Keys.onEnterPressed: view.shell.submit()
        Keys.onEscapePressed: view.shell.buffer = ""
        Component.onCompleted: forceActiveFocus()
        onEnabledChanged: if (enabled) forceActiveFocus()
    }

    // Under the hands: what PAM says (a wrong password in love), then the brief.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.min(view.py(0.75), view.height - height - 24)
        width: Math.min(parent.width - 48, 520)
        spacing: 14

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: view.shell.status
            color: view.shell.failed ? Theme.love : Theme.fgMuted
            size: Theme.fontSmall
        }
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
