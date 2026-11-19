import QtQuick
import Quickshell
import qs.services
import qs.components

// The one agent item of theme root-agentic, in place of the three Claude items (waiting, threads, usage):
// what needs me (permission requests, question dialogs and rounds, sessions waiting for me, threads that
// need me) as a gold count, else how many threads are at work, and the plan usage from 70 %.
// Click: the panel on the tab that needs me first (or the main chat); middle: that tab's terminal;
// right: dismiss the "waiting" marks, as the old item did.
BarItem {
    id: root
    hpad: 6
    spacing: 4

    // Tab names, each once: a request's tab ("" for a session without one counts under its name).
    readonly property var needs: {
        const seen = [];
        const add = n => { if (n && seen.indexOf(n) < 0) seen.push(n); };
        Agentic.requests.forEach(r => add(r.tab || r.name || r.id));
        ClaudeWaiting.list.forEach(s => add(s.name));
        ClaudeThreads.live.filter(t => t.state === "needs you").forEach(t => add(t.name));
        return seen;
    }
    readonly property int working: ClaudeThreads.working
    readonly property bool active: needs.length > 0 || ClaudeThreads.live.length > 0 || ClaudeUsage.high
    // The panel's tab for a name: the main chat's session is "main-chat", a thread's tab is its name.
    function tabOf(n) {
        if (n === "main" || n === "main-chat") return "main";
        return Agentic.tabs.indexOf(n) >= 0 || ClaudeThreads.list.some(t => t.name === n) ? n : "";
    }
    readonly property string first: needs.map(tabOf).find(t => t !== "") || (needs.length > 0 ? "home" : "main")
    readonly property color tint: needs.length > 0 ? Theme.gold : (working > 0 ? Theme.fg : Theme.fgMuted)

    visible: Agentic.enabled && active
    tip: {
        const parts = [];
        if (needs.length > 0) parts.push("Needs you: " + needs.join(", "));
        const r = Agentic.requests.length;
        if (r > 0) parts.push(r + (r === 1 ? " request waits" : " requests wait") + " for an answer in the panel");
        if (ClaudeThreads.tooltip !== "") parts.push("Threads\n" + ClaudeThreads.tooltip);
        if (ClaudeUsage.high) parts.push("Usage\n" + ClaudeUsage.tooltip);
        parts.push("Click: open the panel · middle: terminal · right: dismiss waiting");
        return parts.join("\n\n");
    }

    onLeftClicked: Agentic.show(first)
    onMiddleClicked: Agentic.terminal(first === "home" ? "main" : first)
    onRightClicked: Quickshell.execDetached([Host.home + "/.config/scripts/claude-jump.sh", "--clear"])

    Glyph { anchors.verticalCenter: parent.verticalCenter; text: "󰚩"; color: root.tint }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        readonly property int n: root.needs.length > 0 ? root.needs.length : root.working
        visible: n > 0
        text: String(n)
        color: root.tint
        size: Theme.fontSmall
        bold: true
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: ClaudeUsage.high
        text: Math.round(ClaudeUsage.peak) + "%"
        color: ClaudeUsage.peak >= 90 ? Theme.love : Theme.gold
        size: Theme.fontSmall
        bold: true
    }
}
