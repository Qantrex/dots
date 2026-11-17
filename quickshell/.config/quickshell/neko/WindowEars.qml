import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// nekosec only (shell.qml loads it while Neko.enabled): cat ears on every window.
// One click-through layer per screen, above the windows, draws a pair of ears on
// the top edge of each window of that screen's workspace. Hyprland draws no shapes
// on windows, so the positions come from `hyprctl clients/monitors`, re-read on
// Hyprland's window and workspace events (and every 2 s, for drags and resizes).
// The focused window's ears are bright and twitch when it gets focus; fullscreen
// windows have none.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}                              // never takes a click
    WlrLayershell.namespace: "qs-neko-ears"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var windows: []                     // {address, x, y, w, h, focused}
    property bool settling: false                // a workspace is sliding in: hide

    readonly property real earW: 26
    readonly property real earH: 16

    function read(clients, monitors) {
        const mon = monitors.find(m => m.name === win.screen.name);
        if (!mon) { windows = []; return; }
        // By name: special workspaces have no id, and an inactive one is "".
        const ws = [mon.activeWorkspace.name, mon.specialWorkspace ? mon.specialWorkspace.name : ""].filter(n => n);
        const out = [];
        for (const c of clients) {
            if (!c.mapped || c.hidden || c.fullscreen > 0) continue;
            if (!ws.includes(c.workspace.name)) continue;
            out.push({ address: c.address, x: c.at[0] - mon.x, y: c.at[1] - mon.y,
                       w: c.size[0], h: c.size[1], focused: c.focusHistoryID === 0 });
        }
        windows = out;
    }

    Process {
        id: query
        command: ["sh", "-c", "hyprctl -j clients; printf '\\n#\\n'; hyprctl -j monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n#\n");
                try { win.read(JSON.parse(parts[0]), JSON.parse(parts[1])); } catch (e) {}
            }
        }
    }
    function refresh() { if (!query.running) query.running = true; }

    // Read soon after an event, and again when the open/move animation is done.
    Timer { id: soon; interval: 40; onTriggered: win.refresh() }
    Timer { id: later; interval: 420; onTriggered: { win.refresh(); win.settling = false; } }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: win.refresh() }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            const n = ev.name;
            if (n === "workspacev2" || n === "focusedmonv2" || n === "activespecialv2") win.settling = true;
            if (/^(openwindow|closewindow|movewindowv2|activewindowv2|workspacev2|focusedmonv2|activespecialv2|changefloatingmode|fullscreen|resizewindow)$/.test(n)) {
                soon.restart();
                later.restart();
            }
        }
    }

    Repeater {
        model: win.windows
        delegate: Item {
            id: pair
            required property var modelData
            x: modelData.x
            y: modelData.y - win.earH + 3
            width: modelData.w
            height: win.earH
            opacity: win.settling ? 0 : (modelData.focused ? 1 : 0.55)
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            readonly property bool focused: modelData.focused
            onFocusedChanged: if (focused) { l.twitch(); r.twitch(); }

            WindowEar { id: l; x: Math.min(34, pair.width * 0.12); focused: pair.focused }
            WindowEar { id: r; x: pair.width - width - Math.min(34, pair.width * 0.12); mirrored: true; focused: pair.focused }
        }
    }

    component WindowEar: Canvas {
        id: ear
        property bool mirrored: false
        property bool focused: false
        width: win.earW
        height: win.earH
        transformOrigin: Item.Bottom
        onFocusedChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const tx = mirrored ? w * 0.7 : w * 0.3;
            ctx.beginPath();
            ctx.moveTo(0, h);
            ctx.lineTo(tx - 2, 2.5);
            ctx.quadraticCurveTo(tx, 0, tx + 2, 2.5);
            ctx.lineTo(w, h);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, w, h);
            g.addColorStop(0, mirrored ? Neko.lilac : Theme.accent);
            g.addColorStop(1, mirrored ? Neko.mint : Neko.lilac);
            ctx.fillStyle = g;
            ctx.fill();
            // the inner ear
            ctx.beginPath();
            ctx.moveTo(w * 0.28, h);
            ctx.lineTo(tx, h * 0.38);
            ctx.lineTo(w * 0.72, h);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(1, 0.94, 0.98, ear.focused ? 0.45 : 0.25);
            ctx.fill();
        }
        function twitch() { anim.restart(); }
        SequentialAnimation {
            id: anim
            RotationAnimation { target: ear; to: ear.mirrored ? 14 : -14; duration: 90; easing.type: Easing.OutQuad }
            RotationAnimation { target: ear; to: 0; duration: 300; easing.type: Easing.OutBack }
        }
        // now and then, on their own
        Timer {
            running: ear.visible
            repeat: true
            interval: 9000 + Math.random() * 30000
            onTriggered: { if (Math.random() < 0.4) ear.twitch(); interval = 9000 + Math.random() * 30000; }
        }
    }
}
