pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the main Claude chat's threads are doing, from ~/.cache/agentic-threads.json, which the session hook in
// ~/Projects/claude-config writes on every tool call of a thread (code only). Stale entries (no news for 2 h)
// don't count.
Singleton {
    id: root

    property var list: []
    readonly property var live: list.filter(t => Date.now() / 1000 - t.at < 7200 && t.state !== "idle")
    readonly property int working: live.filter(t => t.state === "working").length
    readonly property bool needsMe: live.some(t => t.state === "needs you")
    readonly property string first: (live.find(t => t.state === "needs you") || live[0] || {}).name || "main"

    readonly property string tooltip: list.filter(t => Date.now() / 1000 - t.at < 7200).map(t => {
        const mins = Math.max(0, Math.round((Date.now() / 1000 - t.since) / 60))
        return t.name + " · " + t.state + (t.state === "working" ? " for " + mins + " min" : "")
            + (t.detail ? "\n   " + t.detail.slice(0, 70) : "")
    }).join("\n")

    function parse() {
        try {
            const j = JSON.parse(file.text())
            list = Array.isArray(j) ? j : []
        } catch (e) {
            list = []
        }
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/agentic-threads.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse()
        onLoadFailed: root.list = []
    }

    // The hook replaces the file atomically, which a file watch can miss.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: file.reload()
    }
}
