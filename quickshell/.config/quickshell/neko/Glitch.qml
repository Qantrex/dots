import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services

// nekosec only: the glitch between two wallpapers (Neko.glitchTo / `qs ipc call neko
// glitch PATH`). For about half a second a layer just above the wallpaper, under
// every window, shows the current picture cut into shifted bands with pink and
// mint colour splits. At the peak the first screen switches hyprpaper to the new
// picture underneath, and the bands carry on with that one. With no PATH it only
// glitches the current picture. Works for any wallpaper: the daemon's changes,
// `neko next`, and picks in the launcher.
PanelWindow {
    id: win
    required property var modelData
    property bool primary: false         // this screen's layer runs the hyprpaper switch
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    visible: phase > 0
    WlrLayershell.namespace: "qs-neko-glitch"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property string fromSrc: ""
    property string toSrc: ""
    property int phase: 0                 // 0 idle, 1 the old picture, 2 the new one
    property double t0: 0
    property double t2: 0
    property var bands: []
    property real split: 10
    property var bars: []

    readonly property string cur: {
        const p = phase === 2 ? toSrc : fromSrc;
        return p ? "file://" + p : "";
    }
    readonly property size decode: Qt.size(Math.round(width), Math.round(height))

    // Decoded ahead, so the bands have something to show at once.
    Image { id: fromImg; visible: false; source: win.fromSrc ? "file://" + win.fromSrc : ""; sourceSize: win.decode; asynchronous: true }
    Image { id: toImg; visible: false; source: win.toSrc ? "file://" + win.toSrc : ""; sourceSize: win.decode; asynchronous: true }

    Connections {
        target: Neko
        function onGlitchRequested(to) { win.start(to); }
        function onWallpaperChanged() { if (win.phase === 0) win.fromSrc = Neko.wallpaper; }
    }
    Component.onCompleted: fromSrc = Neko.wallpaper

    function start(to) {
        fromSrc = Neko.wallpaper;
        toSrc = to;
        phase = 1;
        t0 = Date.now();
        shuffle();
        tick.restart();
    }

    function shuffle() {
        const h = height, w = width;
        const b = [];
        const n = 9 + Math.floor(Math.random() * 8);
        for (let i = 0; i < n; i++) {
            const bh = 6 + Math.random() * h * 0.09;
            b.push({ y: Math.random() * (h - bh), h: bh, dx: (Math.random() - 0.5) * w * 0.18 });
        }
        bands = b;
        split = 6 + Math.random() * 18;
        const r = [];
        for (let i = 0; i < 7; i++)
            r.push({ x: Math.random() * w, y: Math.random() * h, w: 40 + Math.random() * w * 0.35,
                     h: 2 + Math.random() * 9, c: Math.random() < 0.5 ? 0 : (Math.random() < 0.5 ? 1 : 2) });
        bars = r;
    }

    Timer {
        id: tick
        interval: 45
        repeat: true
        onTriggered: {
            const now = Date.now();
            win.shuffle();
            if (win.phase === 1) {
                const el = now - win.t0;
                if (!win.toSrc) {
                    if (el >= 380) { win.phase = 0; stop(); }
                } else if (el >= 170 && (toImg.status === Image.Ready || el > 1200)) {
                    if (win.primary) {
                        Quickshell.execDetached(["hyprctl", "-q", "hyprpaper", "wallpaper", "," + win.toSrc]);
                        Neko.wallpaper = win.toSrc;
                    }
                    win.phase = 2;
                    win.t2 = now;
                }
            } else if (win.phase === 2 && now - win.t2 >= 260) {
                win.phase = 0;
                stop();
                win.fromSrc = win.toSrc;
            }
        }
    }

    // Colour-split copies of the whole picture: pink to one side, mint to the other.
    Image {
        x: win.split; width: win.width; height: win.height
        source: win.cur; sourceSize: win.decode; asynchronous: true
        opacity: 0.38
        layer.enabled: true
        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: Theme.accent }
    }
    Image {
        x: -win.split; width: win.width; height: win.height
        source: win.cur; sourceSize: win.decode; asynchronous: true
        opacity: 0.32
        layer.enabled: true
        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: Neko.mint }
    }

    // The bands: strips of the picture, shifted sideways.
    Repeater {
        model: win.bands
        delegate: Item {
            required property var modelData
            y: modelData.y; width: win.width; height: modelData.h
            clip: true
            Image {
                x: modelData.dx; y: -modelData.y
                width: win.width; height: win.height
                source: win.cur; sourceSize: win.decode; asynchronous: true
            }
        }
    }

    // Bars of pure colour.
    Repeater {
        model: win.bars
        delegate: Rectangle {
            required property var modelData
            x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
            color: modelData.c === 0 ? Theme.accent : modelData.c === 1 ? Neko.mint : Theme.bgOpaque
            opacity: 0.85
        }
    }
}
