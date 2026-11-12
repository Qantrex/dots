pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The state of the shell scripts in ~/.config/scripts that the keybinds also
// use. Each prints JSON on `status` ({text, alt, class, tooltip}); after a
// change the script calls `qs ipc call bar refresh <name>`, and a slow timer
// catches anything else (e.g. a manual fusermount3 -u on the vault).
Singleton {
    id: root

    readonly property string dir: Host.home + "/.config/scripts/"

    readonly property ScriptState vault: ScriptState { name: "vault"; interval: 30000 }
    readonly property ScriptState touchpad: ScriptState { name: "touchpad"; interval: 0; enabled: Host.isLaptop }
    readonly property ScriptState powerprofile: ScriptState { name: "powerprofile"; interval: 30000; enabled: Host.isLaptop }
    readonly property ScriptState ai: ScriptState { name: "ai"; file: "ai-webui"; interval: 10000; enabled: Host.isLaptop }

    function byName(n) { return ({ vault, touchpad, powerprofile, ai })[n] ?? null; }
    function refresh(n) {
        const s = byName(n);
        if (s) s.refresh();
        else for (const x of [vault, touchpad, powerprofile, ai]) x.refresh();
    }
    // Runs `<script> <args...>`; the script itself triggers the refresh.
    function run(n, args) {
        const s = byName(n);
        if (!s) return;
        Quickshell.execDetached([dir + s.file + ".sh"].concat(args));
    }
    function runThen(n, args, cmd) {
        const s = byName(n);
        if (!s) return;
        Quickshell.execDetached(["sh", "-c", '"$0" "$@" && ' + cmd, dir + s.file + ".sh"].concat(args));
    }

    component ScriptState: Scope {
        id: s
        required property string name
        property string file: name
        property int interval: 30000
        property bool enabled: true

        property string text: ""
        property string state: ""        // "alt", else the first class
        property var classes: []
        property string tooltip: ""
        property bool loaded: false

        function refresh() { if (enabled) proc.running = true; }
        function has(c) { return classes.includes(c); }

        Process {
            id: proc
            running: s.enabled
            command: [root.dir + s.file + ".sh", "status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const j = JSON.parse(text.trim().split("\n").pop());
                        const cls = Array.isArray(j.class) ? j.class : (j.class ? [j.class] : []);
                        s.text = j.text ?? "";
                        s.classes = cls;
                        s.state = j.alt ?? cls[0] ?? "";
                        s.tooltip = j.tooltip ?? "";
                        s.loaded = true;
                    } catch (e) {
                        console.warn("scripts:", s.name, "status is not JSON:", text);
                    }
                }
            }
        }
        Timer {
            interval: Math.max(1000, s.interval)
            running: s.enabled && s.interval > 0
            repeat: true
            onTriggered: s.refresh()
        }
    }
}
