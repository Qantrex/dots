pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Claude sessions that wait for me (finished a turn or ask for a permission), from
// ~/.cache/claude-waiting.json, which the session hook in ~/Projects/claude-config
// rewrites on every change.
Singleton {
    id: root

    property var list: []
    readonly property int count: list.length

    readonly property string tooltip: list.map(s => {
        const mins = Math.max(0, Math.round((Date.now() / 1000 - s.since) / 60))
        return s.name + " · " + (mins < 1 ? "just now" : mins + " min") + (s.why ? "\n   " + s.why.slice(0, 70) : "")
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
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/claude-waiting.json"
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
