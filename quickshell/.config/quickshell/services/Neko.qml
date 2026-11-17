pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The nekosec theme's extras in the shell: the catgirl avatar and mood in the bar,
// the opsec status, kaomoji on notifications and the nya sound.
//
// Off unless the current theme renders neko.json (only nekosec does, from
// theme/themes/nekosec/templates/neko.json), so every other theme looks exactly as
// before. The picture daemon (`neko`, ~/.local/bin) writes ~/.cache/nekosec/state.json
// and calls `qs ipc call neko refresh` after each change.
Singleton {
    id: root

    readonly property bool enabled: conf.loaded && cfg.enabled === true
    readonly property string bin: cfg.bin || "neko"

    // From the daemon's state.
    property string avatar: ""
    property int version: 0
    property string kaomoji: "(=^･ω･^=)"
    property string threat: ""
    property string subject: ""
    property string artist: ""
    property string shown: ""
    property string mode: "sfw"
    property bool paused: false

    // From `neko hud`.
    property var vpn: []
    property bool tor: false
    property bool firewall: false
    property int cams: 0
    property int mics: 0
    readonly property int watchers: cams + mics

    function refresh() { conf.reload(); state.reload(); settings.reload(); hud.running = true; }
    function run(args) { Quickshell.execDetached([root.bin].concat(args)); }
    function next() { run(["next"]); }
    function togglePause() { run([root.paused ? "resume" : "pause"]); }
    function save() { run(["save"]); }
    function openPage() { run(["open"]); }
    function sound(kind) { if (root.enabled) run(["sound", kind]); }

    // A kaomoji for a notification, by urgency (0 low, 1 normal, 2 critical).
    function notifFace(urgency) {
        return urgency >= 2 ? "(=ↀωↀ=)!!" : urgency === 0 ? "(=-ω-=)" : "(=^･ω･^=)";
    }

    FileView {
        id: conf
        path: Host.home + "/dotfiles/theme/current/neko.json"
        blockLoading: true
        printErrors: false
        property bool loaded: false
        onLoaded: loaded = true
        onLoadFailed: loaded = false
        JsonAdapter {
            id: cfg
            property bool enabled: false
            property string bin: ""
        }
    }

    FileView {
        id: state
        path: Host.home + "/.cache/nekosec/state.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (s.avatar && s.avatar !== root.avatar) root.avatar = s.avatar;
                root.version += 1;
                root.kaomoji = s.kaomoji || root.kaomoji;
                root.threat = s.threat || "";
                root.subject = s.subject || "";
                root.artist = s.artist || "";
                root.shown = s.shown || "";
            } catch (e) {}
        }
    }

    FileView {
        id: settings
        path: Host.home + "/.config/nekosec/settings.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.mode = s.mode || "sfw";
                root.paused = s.paused === true;
            } catch (e) {}
        }
    }

    Process {
        id: hud
        command: [root.bin, "hud"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const h = JSON.parse(text);
                    root.vpn = h.vpn || [];
                    root.tor = h.tor === true;
                    root.firewall = h.firewall === true;
                    root.cams = h.cams || 0;
                    root.mics = h.mics || 0;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 15000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: hud.running = true
    }

    IpcHandler {
        target: "neko"
        // `neko` calls this after a new picture; `theme set` reloads the shell's theme.
        function refresh(): void { root.refresh(); }
    }

    // A theme switch swaps theme/current; pick up whether neko.json is there.
    Connections {
        target: Theme
        function onBgOpaqueChanged() { conf.reload(); }
    }
}
