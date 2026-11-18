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
    readonly property color lilac: cfg.lilac || Theme.fgMuted
    readonly property color mint: cfg.mint || Theme.fgMuted

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
    property var stone: null          // {cx, cy, r, w, h}: the seeing stone on the wallpaper, in its pixels
    property bool stoneOpen: false    // the "look into the stone" panel
    property string wallpaper: ""     // what hyprpaper shows now (neko/Glitch.qml glitches it)

    // Glitch over to another wallpaper (or, with "", just glitch the current one).
    // neko/Glitch.qml does it and switches hyprpaper underneath at the peak.
    signal glitchRequested(string to)
    function glitchTo(path) {
        if (root.enabled) root.glitchRequested(path || "");
        else if (path) Quickshell.execDetached(["hyprctl", "-q", "hyprpaper", "wallpaper", "," + path]);
    }

    // From `neko hud`.
    property var vpn: []
    property bool tor: false
    property bool firewall: false
    property int cams: 0
    property int mics: 0
    property var camApps: []
    property var micApps: []
    readonly property int watchers: cams + mics

    function refresh() { conf.reload(); state.reload(); settings.reload(); hud.running = true; active.running = true; }
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
            property string lilac: ""
            property string mint: ""
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
                root.stone = s.stone || null;
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

    // `eDP-1: /path` per monitor; the first is enough (one picture on every screen).
    Process {
        id: active
        command: ["hyprctl", "hyprpaper", "listactive"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/:\s*(\/\S.*)$/m);
                if (m) root.wallpaper = m[1].trim();
            }
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
                    root.camApps = h.cam_apps || [];
                    root.micApps = h.mic_apps || [];
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 15000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: { hud.running = true; if (!root.wallpaper) active.running = true; }
    }

    IpcHandler {
        target: "neko"
        // `neko` calls this after a new picture; `theme set` reloads the shell's theme.
        function refresh(): void { root.refresh(); }
        // `qs ipc call neko stone`: open or close the seeing stone's panel.
        // `qs ipc call neko glitch PATH`: the daemon's changes (PATH "" = only a glitch).
        function glitch(path: string): void { root.glitchTo(path); }
        function stone(): void { root.stoneOpen = !root.stoneOpen; if (root.stoneOpen) hud.running = true; }
    }

    // A theme switch swaps theme/current; pick up whether neko.json is there.
    Connections {
        target: Theme
        function onBgOpaqueChanged() { conf.reload(); }
    }
}
