pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The agent panel of the theme root-agentic (agentic/Panel.qml): what it shows and the
// ways in from outside (`dock`, the theme hooks).
//
// Off unless the current theme renders agentic.json (only root-agentic does, from
// theme/themes/root-agentic/templates/agentic.json), so every other theme keeps the shell it
// had: no panel window, no process and no timer exist while this is off. Everything here runs
// only while the panel is open.
//
// The panel never talks to Claude itself. It reads what `agentic-shell` prints (the transcript
// Claude Code writes, the inbox, the brief) and sends through `thread send`, which types into
// the session's own terminal in tmux. The sessions stay normal interactive Claude Code.
Singleton {
    id: root

    // The desktop PC keeps its docked terminal on workspace 14 for now.
    readonly property bool enabled: conf.loaded && cfg.enabled === true && Host.isLaptop
    readonly property real widthShare: cfg.width > 0 ? cfg.width : 0.4
    readonly property int minWidth: cfg.minWidth > 0 ? cfg.minWidth : 560
    readonly property string bin: cfg.bin || Host.home + "/.local/bin"

    property bool open: false
    property string target: "main"    // "main", a thread's name, or "home" (brief and inbox)

    // From `agentic-shell home`.
    property var threads: []          // [{name, state, detail, since}], the windows of tmux "main"
    property var brief: []            // lines of `agentic brief`
    property var inbox: []            // [{at, level, source, text, untrusted, new}], newest first
    property int newCount: 0          // inbox events since the home tab was last looked at

    // What is typed but not sent yet, per tab, so a tab change loses nothing.
    property var drafts: ({})

    property bool sending: false
    signal sent(string to)
    signal sendFailed(string to, string why)

    readonly property var tabs: ["main"].concat(threads.map(t => t.name), ["home"])

    // A thread's state as the session hook last wrote it (every 2 s), else as `home` saw it.
    function stateOf(name) {
        const t = ClaudeThreads.list.find(x => x.name === name) || threads.find(x => x.name === name);
        return t ? t.state || "" : "";
    }
    function detailOf(name) {
        const t = ClaudeThreads.list.find(x => x.name === name) || threads.find(x => x.name === name);
        return t ? t.detail || "" : "";
    }

    function show(to) {
        if (!enabled) return;
        if (to && /^[A-Za-z0-9._-]+$/.test(to)) target = to;
        open = true;
    }
    function hide() { open = false; }
    function step(by) {
        const i = tabs.indexOf(target);
        target = tabs[((i < 0 ? 0 : i) + by + tabs.length) % tabs.length];
    }

    // The panel's own keys, wherever the focus is inside it. True when the key was one of them.
    function key(e) {
        const ctrl = e.modifiers & Qt.ControlModifier;
        if (e.key === Qt.Key_Escape) hide();
        else if (ctrl && e.key === Qt.Key_Tab) step(1);
        else if (ctrl && e.key === Qt.Key_Backtab) step(-1);
        else if (ctrl && e.key === Qt.Key_T) terminal();
        else return false;
        e.accepted = true;
        return true;
    }

    function refresh() {
        if (!enabled || home.running) return;
        home.seen = open && target === "home";
        home.running = true;
    }

    // The real Claude Code terminal of what the panel shows (the foot panel `dock` always had).
    function terminal() {
        Quickshell.execDetached([bin + "/dock", "term", target === "home" ? "main" : target]);
    }

    function send(to, text) {
        if (sending || !text.trim()) return;
        sending = true;
        sender.to = to;
        sender.command = [bin + "/thread", "send", to, text];
        sender.running = true;
    }

    onEnabledChanged: if (!enabled) open = false
    onOpenChanged: if (open) refresh()
    onTargetChanged: if (open && target === "home") refresh()

    // root and root-agentic share every colour, so nothing else tells a theme change.
    Connections {
        target: Theme
        function onReloaded() { conf.reload(); }
    }

    FileView {
        id: conf
        path: Quickshell.env("QS_AGENTIC_CONF") || Host.home + "/dotfiles/theme/current/agentic.json"
        blockLoading: true
        printErrors: false
        property bool loaded: false
        onLoaded: loaded = true
        onLoadFailed: loaded = false
        JsonAdapter {
            id: cfg
            property bool enabled: false
            property real width: 0
            property int minWidth: 0
            property string bin: ""
        }
    }

    Process {
        id: home
        property bool seen: false
        command: [root.bin + "/agentic-shell", "home"].concat(seen ? ["--seen"] : [])
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const h = JSON.parse(text);
                    root.brief = h.brief || [];
                    root.inbox = h.inbox || [];
                    root.newCount = h.new || 0;
                    root.threads = h.threads || [];
                    // The thread it showed is gone: back to the main chat.
                    if (root.tabs.indexOf(root.target) < 0) root.target = "main";
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 10000
        running: root.open
        repeat: true
        onTriggered: root.refresh()
    }

    // The text goes as one argument, never through a shell.
    Process {
        id: sender
        property string to: ""
        stderr: StdioCollector { id: complaint }
        onExited: (code, status) => {
            root.sending = false;
            if (code === 0) { delete root.drafts[to]; root.sent(to); }
            else root.sendFailed(to, complaint.text.trim().replace(/^thread send: /, "") || "Could not send.");
        }
    }

    IpcHandler {
        target: "agentic"
        function toggle(): void { if (root.open) root.hide(); else root.show("main"); }
        // Named open, not show: `qs ipc call agentic show x` is read as the `qs ipc show` subcommand.
        function open(to: string): void { root.show(to || "main"); }
        function hide(): void { root.hide(); }
        function refresh(): void { conf.reload(); root.refresh(); }
        // off: this theme has no panel. `dock` and `agentic-shell snapshot` read this.
        function status(): string { return !root.enabled ? "off" : (root.open ? "shown " + root.target : "hidden"); }
    }
}
