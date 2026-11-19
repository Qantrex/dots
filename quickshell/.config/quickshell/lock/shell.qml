import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// The lock screen of theme root-agentic, started by `agentic-lock`. A Quickshell config of its own, run as
// its own process like hyprlock, so that a reload of the desktop's shell never touches a locked session. It
// doesn't watch its files either: it shares services/ and components/ with the desktop's shell, and an edit
// there while I'm away would otherwise reload the lock and drop what I've typed.
// hyprlock stays the lock of theme root and the fallback when this one can't lock (exit 3).
// Settings come from the environment (`agentic-lock` sets them):
//   AGENTIC_LOCK_TRIAL=N        unlock by itself after N seconds (the first try), 0 = a real lock
//   AGENTIC_LOCK_BRIEF=full|counts|off   how much of `agentic brief` shows under the clock
//   AGENTIC_LOCK_PAM=hyprlock, AGENTIC_LOCK_PAM_DIR=/etc/pam.d   the PAM service (tests use pam_permit/pam_deny)
//   AGENTIC_LOCK_PREVIEW=1      tests: a small window without focus instead of a lock, typed into over IPC
//   AGENTIC_LOCK_PREVIEW_SIZE=WxH  its size (default 720x450, the laptop's 16:10)
ShellRoot {
    id: root
    settings.watchFiles: false

    readonly property int trial: parseInt(Quickshell.env("AGENTIC_LOCK_TRIAL") || "0") || 0
    readonly property string briefMode: Quickshell.env("AGENTIC_LOCK_BRIEF") || "counts"
    readonly property bool preview: Quickshell.env("AGENTIC_LOCK_PREVIEW") === "1"

    property string buffer: ""           // the password being typed, shared by the field on every screen
    property string status: ""
    property bool failed: false
    property bool checking: false
    property int left: trial
    readonly property string trialEnd: Qt.formatTime(new Date(Date.now() + trial * 1000), "HH:mm:ss")
    property var brief: []
    property bool done: false

    // The keyboard after a suspend (2026-11-19): a lock started by before-sleep had the keyboard, lost it as
    // the suspend began, and after resume Hyprland didn't give it back until a click. Hyprland gives a lock
    // surface the keyboard on pointer motion (and on a new frame, but only when nothing has focus, and a
    // real lock draws one frame a minute), never on a key press, and the client can't take it. So when no
    // screen of the lock has had the keyboard for half a second, ask Hyprland for a pointer motion: the
    // cursor moved to where it already is (`hl.dsp.cursor.move` warps and simulates a movement). Every
    // 2 s after that, at most 30 times per loss. The preview (tests) only logs it, so a test never moves
    // the focus of the desktop it runs on.
    property int keyboardViews: 0          // LockView windows that have the keyboard
    property int focusTries: 0
    onKeyboardViewsChanged: if (keyboardViews > 0) focusTries = 0
    Timer {
        interval: root.focusTries === 0 ? 500 : 2000
        repeat: true
        running: (lock.secure || root.preview) && !root.done && root.keyboardViews <= 0 && root.focusTries < 30
        onTriggered: {
            root.focusTries += 1;
            console.info("agentic-lock: no screen has the keyboard, asking Hyprland for it (" + root.focusTries + ")"
                         + (root.preview ? " [preview: not sent]" : ""));
            if (!root.preview) refocus.running = true;
        }
    }
    Process {
        id: refocus
        command: ["sh", "-c", 'p=$(hyprctl cursorpos) && hyprctl dispatch "hl.dsp.cursor.move({ x = ${p%%,*}, y = ${p##*, } })"']
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "ok") console.warn("agentic-lock: hyprctl said: " + text.trim()) }
    }

    function submit() {
        if (checking || done || buffer === "") return;
        checking = true;
        status = "Checking …";
        failed = false;
        if (!pam.start()) { checking = false; failed = true; status = "Can't check the password (PAM didn't start)"; }
    }
    function unlock(why) {
        if (done) return;
        done = true;
        buffer = "";
        console.info("agentic-lock: unlocked (" + why + ")");
        lock.locked = false;
        quitSoon.start();
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.env("AGENTIC_LOCK_PAM_DIR") || "/etc/pam.d"
        config: Quickshell.env("AGENTIC_LOCK_PAM") || "hyprlock"
        onPamMessage: {
            if (responseRequired) respond(root.buffer);
            else if (message !== "") root.status = message;
        }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) { root.unlock("password"); return; }
            root.failed = true;
            root.buffer = "";
            console.info("agentic-lock: password not accepted");
            root.status = result === PamResult.MaxTries ? "Too many tries, wait a moment" : "Wrong password";
        }
        onError: err => {
            root.checking = false;
            root.failed = true;
            root.status = "Can't check the password: " + PamError.toString(err);
        }
    }

    WlSessionLock {
        id: lock
        locked: !root.preview
        WlSessionLockSurface {
            color: "#000000"
            LockView { anchors.fill: parent; shell: root }
        }
    }

    // The compositor has to confirm the lock; when it doesn't (another lock runs, no support), give up so
    // that `agentic-lock` can start hyprlock. Without unlocking first: if the lock does take hold late (a
    // suspend in between), the session stays locked and hyprlock takes it over.
    Timer {
        interval: 3000
        running: !root.preview && !lock.secure && !root.done
        onTriggered: { console.warn("agentic-lock: the compositor did not confirm the lock"); Qt.exit(3); }
    }
    Timer { id: quitSoon; interval: 300; onTriggered: Qt.quit() }
    Timer {
        interval: 1000
        repeat: true
        running: root.trial > 0 && !root.done
        onTriggered: { root.left -= 1; if (root.left <= 0) root.unlock("trial time over"); }
    }

    Process {
        running: root.briefMode !== "off"
        command: [Quickshell.env("HOME") + "/.local/bin/agentic", "brief", "--print"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim()).filter(l => l !== "");
                // counts: only the lines that say how many, never what (task names, mail subjects).
                root.brief = root.briefMode === "full" ? lines : lines.filter(l => /^\d/.test(l) || l.startsWith("Claude this week"));
            }
        }
    }

    // Tests only: the lock as an ordinary window instead of a lock (tests open it on an unused workspace
    // without focus, and type into it over IPC).
    LazyLoader {
        id: previewLoader
        active: root.preview
        FloatingWindow {
            property alias view: previewView
            title: "agentic-lock preview"
            implicitWidth: parseInt(Quickshell.env("AGENTIC_LOCK_PREVIEW_SIZE") || "720x450") || 720
            implicitHeight: parseInt((Quickshell.env("AGENTIC_LOCK_PREVIEW_SIZE") || "720x450").split("x")[1]) || 450
            color: "#000000"
            LockView { id: previewView; anchors.fill: parent; shell: root }
        }
    }
    IpcHandler {
        target: "locktest"
        enabled: root.preview
        function type(text: string): void { root.buffer = text; }
        function submit(): void { root.submit(); }
        // Saves what the preview shows as a PNG, without the window being on a visible workspace.
        function shot(path: string): void { previewLoader.item.view.grabToImage(r => r.saveToFile(path)); }
        function state(): string {
            return JSON.stringify({ status: root.status, failed: root.failed, checking: root.checking, done: root.done,
                                    left: root.left, brief: root.brief, typed: root.buffer.length });
        }
    }
}
