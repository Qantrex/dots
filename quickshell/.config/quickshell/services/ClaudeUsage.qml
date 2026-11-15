pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Claude plan usage, read from ~/.cache/claude-usage.json, which the Claude Code
// status line script (~/Projects/claude-config/statusline.sh) writes on every
// status update. The numbers only refresh while a Claude session is running, so
// a window whose reset time has passed counts as reset.
Singleton {
    id: root

    property real five: -1        // percent used, -1 = unknown or reset
    property real week: -1
    property real fiveAt: 0       // unix seconds
    property real weekAt: 0
    property real now: Date.now() / 1000

    readonly property real fiveLive: five >= 0 && fiveAt > now ? five : -1
    readonly property real weekLive: week >= 0 && weekAt > now ? week : -1
    readonly property real peak: Math.max(fiveLive, weekLive)
    readonly property bool high: peak >= 70

    function when(t, withDay) {
        const d = new Date(t * 1000)
        return Qt.formatDateTime(d, withDay ? "ddd HH:mm" : "HH:mm")
    }

    readonly property string tooltip: [
        fiveLive >= 0 ? "5-hour window: " + Math.round(fiveLive) + "% · resets " + when(fiveAt, false) : "",
        weekLive >= 0 ? "Weekly: " + Math.round(weekLive) + "% · resets " + when(weekAt, true) : ""
    ].filter(x => x).join("\n")

    function parse() {
        try {
            const j = JSON.parse(file.text())
            five = j.five_hour ? j.five_hour.used : -1
            fiveAt = j.five_hour && j.five_hour.resets_at ? j.five_hour.resets_at : 0
            week = j.seven_day ? j.seven_day.used : -1
            weekAt = j.seven_day && j.seven_day.resets_at ? j.seven_day.resets_at : 0
        } catch (e) {
            five = -1; week = -1
        }
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/claude-usage.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse()
        onLoadFailed: { root.five = -1; root.week = -1 }
    }

    // Re-read every 30 s: the file may not exist yet when the bar starts, and the
    // status line replaces it atomically, which a file watch can miss. Also moves
    // `now` on, so the icon goes away when a window resets.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: { root.now = Date.now() / 1000; file.reload() }
    }
}
