pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Which thread belongs to which workspace (theme root-agentic only), from `agentic-shell workspaces`: a pin
// from the launcher's Claude mode, else the thread whose folder the workspace's windows work in. Read every
// few seconds and when the focus moves to another workspace; it reads /proc and tmux, no Claude.
Singleton {
    id: root

    property var map: ({})                // "3" -> {thread, how: "folder"|"pin", others, state}
    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 0
    // The thread of the workspace I'm on, or "".
    readonly property string here: (map[String(focusedId)] || {}).thread || ""
    readonly property bool herePinned: (map[String(focusedId)] || {}).how === "pin"

    function of(id) { return map[String(id)] || null; }
    function refresh() { if (Agentic.enabled && !reader.running) reader.running = true; }
    function pin(thread) { pinner.command = [Agentic.bin + "/agentic-shell", "pin", String(focusedId), thread]; pinner.running = true; }
    function unpin() { pin("--clear"); }

    onFocusedIdChanged: refresh()

    Process {
        id: reader
        command: [Agentic.bin + "/agentic-shell", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.map = JSON.parse(text).workspaces || {}; } catch (e) { }
            }
        }
    }
    Process {
        id: pinner
        onExited: root.refresh()
    }
    Timer {
        interval: 5000
        repeat: true
        running: Agentic.enabled
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
