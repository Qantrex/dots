pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Which thread belongs to which workspace (theme root-agentic only), from `agentic-shell workspaces`: a pin
// from the launcher's Claude mode, else the thread whose folder the workspace's windows work in. Read when the
// focus moves to another workspace, when windows open, close or move, and every 30 s for folder changes
// inside a window; it reads /proc and tmux (about 0.2 s of CPU), no Claude. The bar's dot takes the state
// from the threads list, which follows on its own.
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
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindowv2"].indexOf(event.name) >= 0) settle.restart();
        }
    }
    Timer { id: settle; interval: 1500; onTriggered: root.refresh() }

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
        interval: 30000
        repeat: true
        running: Agentic.enabled
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
