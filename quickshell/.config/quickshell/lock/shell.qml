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
    property var brief: []
    property bool done: false

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
        active: root.preview
        FloatingWindow {
            title: "agentic-lock preview"
            implicitWidth: 720; implicitHeight: 450
            color: "#000000"
            LockView { anchors.fill: parent; shell: root }
        }
    }
    IpcHandler {
        target: "locktest"
        enabled: root.preview
        function type(text: string): void { root.buffer = text; }
        function submit(): void { root.submit(); }
        function state(): string {
            return JSON.stringify({ status: root.status, failed: root.failed, checking: root.checking, done: root.done,
                                    left: root.left, brief: root.brief, typed: root.buffer.length });
        }
    }
}
