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
//
// What waits for me (a tool call that needs a yes or a no, a question dialog, a thread's
// questions) comes from `agentic-shell requests` and is answered with `agentic-shell answer`.
// A session's PermissionRequest hook holds such a request and tells this shell through
// `qs ipc call agentic requests`; the terminal asks the same and the first answer counts.
Singleton {
    id: root

    // The desktop PC keeps its docked terminal on workspace 14 for now.
    readonly property bool enabled: conf.loaded && cfg.enabled === true && Host.isLaptop
    readonly property real widthShare: cfg.width > 0 ? cfg.width : 0.4
    readonly property int minWidth: cfg.minWidth > 0 ? cfg.minWidth : 560
    readonly property string bin: cfg.bin || Host.home + "/.local/bin"

    // The panel's text is as large as the terminal's: the theme passes foot's font size, which
    // is in points (1 pt = 96/72 px here, as foot counts it). The shell's own sizes are pixels
    // and smaller, right for the bar but not for reading a conversation.
    readonly property real fontPt: cfg.termFontPt > 0 ? cfg.termFontPt : Theme.fontSize * 72 / 96
    readonly property int fontSize: Math.round(fontPt * 96 / 72)
    readonly property int fontSmall: Math.round(fontSize * Theme.fontSmall / Theme.fontSize)

    property bool open: false
    property string target: "main"    // "main", a thread's name, or "home" (brief and inbox)

    // From `agentic-shell home`.
    property var threads: []          // [{name, state, detail, since}], the windows of tmux "main"
    property var brief: []            // lines of `agentic brief`
    property var inbox: []            // [{at, level, source, text, untrusted, new}], newest first
    property int newCount: 0          // inbox events since the home tab was last looked at

    // From `agentic-shell requests`: [{id, tab, name, tool, at, cwd, kind, title, text, cut, questions}].
    // tab is "main", a thread's name, or "" for a session that has no tab.
    property var requests: []
    property string answering: ""     // the id of the request whose answer is on its way
    property string answerProblem: "" // why the last answer did not go through
    property string answerTab: ""     // and the tab it was for

    // What is typed but not sent yet, per tab, so a tab change loses nothing.
    property var drafts: ({})

    property bool sending: false

    // The voice button, held like SUPER+CTRL+D: `voice press` starts listening, `voice release` sends
    // what was said to the main chat through the inbox (a quick tap keeps it listening until the next
    // one). recording follows `voice status`; voiceState and voiceText the words so far
    // ($XDG_RUNTIME_DIR/voice-live.json: "listening" or "sending", or "" when nothing runs).
    property bool recording: false
    property string voiceState: ""
    property string voiceText: ""

    // The desk row: `agentic-shell grab window|clipboard` gives text for the input box.
    property string grabbing: ""      // "window" or "clipboard" while one is on its way
    signal grabbed(string tab, string text)
    signal grabFailed(string tab, string why)
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

    function requestsOf(tab) { return requests.filter(r => r.tab === tab); }

    // Read the requests again; a call during a read makes one more read after it.
    function ask() {
        if (!enabled) return;
        if (asked.running) asked.again = true;
        else asked.running = true;
    }

    // behavior: "allow" or "deny". what: {answers: {question: label | [labels] | text}} for questions.
    function answer(id, tab, behavior, what) {
        if (answerer.running) return;
        answering = id;
        answerProblem = "";
        answerTab = tab;
        answerer.command = [bin + "/agentic-shell", "answer", id, behavior, JSON.stringify(what || {})];
        answerer.running = true;
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
    function terminal(of) {
        Quickshell.execDetached([bin + "/dock", "term", of || (target === "home" ? "main" : target)]);
    }

    function voicePress() {
        Quickshell.execDetached([bin + "/voice", "press"]);
        recording = !recording;           // at once; voiceCheck confirms it a moment later
        voiceLater.restart();
    }
    function voiceRelease() {
        Quickshell.execDetached([bin + "/voice", "release"]);
        voiceLater.restart();
    }

    // A window shot needs the panel out of the way: it hides, and comes back on the same tab.
    function grab(tab, kind) {
        if (grabbing !== "" || (kind !== "window" && kind !== "clipboard")) return;
        grabbing = kind;
        grabber.tab = tab;
        if (kind === "window") hide();
        grabber.command = [bin + "/agentic-shell", "grab", kind];
        grabber.running = true;
    }

    function send(to, text) {
        if (sending || !text.trim()) return;
        sending = true;
        sender.to = to;
        sender.command = [bin + "/thread", "send", to, text];
        sender.running = true;
    }

    onEnabledChanged: if (!enabled) { open = false; requests = []; asked.last = ""; }
    onOpenChanged: {
        if (open) { refresh(); ask(); }
        else answerProblem = "";
    }

    // A thread that stops with questions changes its mark: look for its round at once.
    readonly property string marks: ClaudeThreads.list.map(t => t.name + " " + t.state).join(",")
    onMarksChanged: if (open) ask()
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
            property real termFontPt: 0
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
        onTriggered: { root.refresh(); root.ask(); }
    }

    // With the panel closed, a slow look as well (a thread round has no hook that calls in).
    Timer {
        interval: 15000
        running: root.enabled && !root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: root.ask()
    }

    Process {
        id: asked
        property bool again: false
        property string last: ""
        command: [root.bin + "/agentic-shell", "requests"]
        stdout: StdioCollector {
            onStreamFinished: {
                // The same list again keeps the cards as they are, with what is chosen and typed.
                if (text === asked.last) return;
                try {
                    root.requests = JSON.parse(text).requests || [];
                    asked.last = text;
                } catch (e) {}
            }
        }
        onExited: if (again) { again = false; Qt.callLater(root.ask); }
    }

    Process {
        id: answerer
        stderr: StdioCollector { id: refusal }
        onExited: (code, status) => {
            root.answering = "";
            if (code !== 0) root.answerProblem = refusal.text.trim().replace(/^agentic-shell answer: /, "") || "Could not answer.";
            root.ask();
        }
    }

    Process {
        id: grabber
        property string tab: ""
        stdout: StdioCollector { id: grabOut }
        onExited: (code, status) => {
            const kind = root.grabbing;
            root.grabbing = "";
            if (kind === "window") root.show(tab);
            let r = {};
            try { r = JSON.parse(grabOut.text); } catch (e) {}
            if (r.insert) root.grabbed(tab, r.insert);
            else root.grabFailed(tab, r.error || "Could not get it.");
        }
    }

    Process {
        id: voiceCheck
        command: [root.bin + "/voice", "status"]
        stdout: StdioCollector { onStreamFinished: root.recording = text.trim() === "recording" }
    }
    Timer { id: voiceLater; interval: 600; onTriggered: voiceCheck.running = true }
    FileView {
        id: voiceLive
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/voice-live.json"
        printErrors: false
        blockLoading: true
    }
    // While a take runs (and a little after, for "sending"), read the words so far.
    Timer {
        interval: 300
        running: root.open && (root.recording || root.voiceState !== "")
        repeat: true
        onTriggered: {
            voiceLive.reload();
            let v = {};
            try { v = JSON.parse(voiceLive.text()); } catch (e) {}
            root.voiceState = v.state || "";
            root.voiceText = v.text || "";
        }
    }
    // SUPER+CTRL+D toggles it from outside the panel too.
    Timer {
        interval: 2000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!voiceCheck.running) voiceCheck.running = true
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
        // The requests changed (`agentic-shell hold`, `release`, `answer`). A closed panel reads them when it opens.
        // Called by the hook when a request comes or goes: the bar item counts them with the panel closed too.
        function requests(): void { root.ask(); }
        // off: this theme has no panel. `dock` and `agentic-shell snapshot` read this.
        function status(): string { return !root.enabled ? "off" : (root.open ? "shown " + root.target : "hidden"); }
    }
}
