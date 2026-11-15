import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.components

// The launcher (replaces wofi): apps, clipboard history, emoji, screenshot,
// wallpaper and power, one search field for all. Tab / Shift+Tab switch modes,
// arrows or Ctrl+J/K move, Enter runs, Esc closes. Apps are ranked by how
// often they were started (~/.local/state/quickshell/.../launcher.json).
PanelWindow {
    id: win

    readonly property bool open: Shell.launcherOpen
    readonly property string mode: Shell.launcherMode
    readonly property var modes: [
        { id: "apps", icon: "󰀻", label: "Apps" },
        { id: "clipboard", icon: "󰅍", label: "Clipboard" },
        { id: "emoji", icon: "󰞅", label: "Emoji" },
        { id: "screenshot", icon: "󰄀", label: "Screenshot" },
        { id: "wallpaper", icon: "󰸉", label: "Wallpaper" },
        { id: "power", icon: "󰐥", label: "Power" }
    ]
    property int selected: 0

    screen: Quickshell.screens.find(s => s.name === Shell.focusedScreen) ?? Quickshell.screens[0]
    visible: open || box.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (!open) return;
        search.text = "";
        selected = 0;
        reload();
        search.forceActiveFocus();
    }
    onModeChanged: { selected = 0; reload(); }

    function close() { Shell.launcherOpen = false; }
    function switchMode(step) {
        const i = modes.findIndex(m => m.id === mode);
        Shell.launcherMode = modes[(i + step + modes.length) % modes.length].id;
    }
    function reload() {
        if (mode === "clipboard") clipProc.running = true;
        if (mode === "wallpaper") wallProc.running = true;
    }

    // --- Data ------------------------------------------------------------
    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher.json")
        watchChanges: false
        printErrors: false
        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }
    function used(id) {
        const c = Object.assign({}, usage.counts);
        c[id] = (c[id] || 0) + 1;
        usage.counts = c;
        usageFile.writeAdapter();
    }

    property var clipLines: []
    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: win.clipLines = text.split("\n").filter(l => l.trim() !== "").slice(0, 200) }
    }

    property var wallpapers: []
    Process {
        id: wallProc
        command: ["find", Host.home + "/Pictures/Wallpapers", "-type", "f", "-iregex", ".*\\.\\(jpe?g\\|png\\|webp\\|bmp\\)$"]
        stdout: StdioCollector { onStreamFinished: win.wallpapers = text.split("\n").filter(l => l).sort() }
    }

    property var emoji: []
    FileView {
        path: Qt.resolvedUrl("../data/emoji.tsv")
        onLoaded: win.emoji = text().split("\n").filter(l => l).map(l => { const [c, n] = l.split("\t"); return { c, n }; })
    }

    // How well `q` matches `s`: 0 = not at all.
    function score(q, s) {
        if (!s) return 0;
        s = s.toLowerCase();
        if (s.startsWith(q)) return 100;
        if (s.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80;
        if (s.includes(q)) return 60;
        let i = 0;
        for (const ch of s) if (ch === q[i]) i++;
        return i === q.length ? 20 : 0;
    }

    // Each item: { icon (glyph) | image (path), title, subtitle, run() }
    readonly property var items: {
        const q = search.text.trim().toLowerCase();
        if (mode === "apps") {
            const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
            return apps.map(a => {
                const s = q ? Math.max(score(q, a.name), 0.6 * score(q, a.genericName),
                                       0.5 * Math.max(0, ...(a.keywords || []).map(k => score(q, k))),
                                       0.4 * score(q, a.id)) : 1;
                return { a, s: s > 0 ? s + 8 * Math.log2(1 + (usage.counts[a.id] || 0)) : 0 };
            }).filter(x => x.s > 0).sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name)).slice(0, 40).map(x => ({
                image: Quickshell.iconPath(x.a.icon, "application-x-executable"),
                title: x.a.name,
                subtitle: x.a.genericName || x.a.comment || "",
                run: () => {
                    used(x.a.id);
                    if (x.a.runInTerminal) Quickshell.execDetached(["foot", "-e"].concat(x.a.command));
                    else x.a.execute();
                }
            }));
        }
        if (mode === "clipboard") {
            return clipLines.filter(l => !q || l.toLowerCase().includes(q)).slice(0, 60).map(l => {
                const text = l.replace(/^\d+\t/, "");
                const img = text.startsWith("[[ binary data");
                return {
                    icon: img ? "󰋩" : "󰅍",
                    title: text.replace(/\s+/g, " ").slice(0, 120),
                    subtitle: "",
                    run: () => Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "clip", l]),
                    remove: () => { Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "clip", l]);
                                    clipLines = clipLines.filter(x => x !== l); }
                };
            });
        }
        if (mode === "emoji") {
            const list = q ? emoji.filter(e => e.n.includes(q)) : emoji;
            return list.slice(0, 64).map(e => ({
                glyphText: e.c, title: e.n, subtitle: "",
                run: () => Quickshell.execDetached(["wl-copy", e.c])
            }));
        }
        if (mode === "screenshot") {
            const shot = m => () => Quickshell.execDetached(["sh", "-c", "sleep 0.3; exec ~/.config/scripts/screenshot.sh " + m]);
            return [
                { icon: "󰩭", title: "Region", subtitle: "Drag a box", run: shot("region") },
                { icon: "", title: "Window", subtitle: "Click a window", run: shot("window") },
                { icon: "󰍹", title: "Monitor", subtitle: "Click a monitor", run: shot("monitor") },
                { icon: "󰍺", title: "All screens", subtitle: "Everything", run: shot("all") }
            ].filter(i => !q || score(q, i.title) > 0);
        }
        if (mode === "wallpaper") {
            return wallpapers.filter(w => !q || w.toLowerCase().includes(q)).map(w => ({
                wallpaper: w, title: w.split("/").pop(), subtitle: "",
                run: () => Quickshell.execDetached(["sh", "-c",
                    'hyprctl -q hyprpaper wallpaper ",$1" && mkdir -p ~/.cache/wallpaper && echo "$1" > ~/.cache/wallpaper/last', "wp", w])
            }));
        }
        if (mode === "power") {
            return [
                { icon: "󰌾", title: "Lock", subtitle: "hyprlock", run: () => Quickshell.execDetached(["hyprlock"]) },
                { icon: "󰤄", title: "Suspend", subtitle: "Locks first", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
                { icon: "󰍃", title: "Log out", subtitle: "Ends the Hyprland session", run: () => Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]) },
                { icon: "󰜉", title: "Restart", subtitle: "", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
                { icon: "󰐥", title: "Shut down", subtitle: "", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
            ].filter(i => !q || score(q, i.title) > 0);
        }
        return [];
    }
    onItemsChanged: if (selected >= items.length) selected = Math.max(0, items.length - 1)

    function activate(i) {
        const it = items[i];
        if (!it) return;
        close();
        it.run();
    }

    readonly property bool grid: mode === "wallpaper" || mode === "emoji"
    readonly property int columns: mode === "wallpaper" ? 3 : (mode === "emoji" ? 8 : 1)

    // --- UI --------------------------------------------------------------
    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: win.open ? 0.35 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        }
    }

    Rectangle {
        id: box
        width: win.mode === "wallpaper" ? 760 : 600
        height: Math.min(content.implicitHeight + 2 * Theme.pad, win.height * 0.7)
        x: (parent.width - width) / 2
        y: parent.height * 0.18
        radius: Theme.radius
        color: Theme.bgSolid
        border.width: 1
        border.color: Theme.borderStrong
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }   // keep clicks inside from closing

        Column {
            id: content
            anchors { fill: parent; margins: Theme.pad }
            spacing: 10

            // Search.
            Rectangle {
                width: parent.width
                height: 44
                radius: Theme.radius
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                Glyph {
                    id: modeIcon
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: (win.modes.find(m => m.id === win.mode) || {}).icon || ""
                    size: 17
                }
                TextInput {
                    id: search
                    anchors { left: modeIcon.right; leftMargin: 12; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontLarge
                    selectionColor: Theme.pressed
                    clip: true
                    onTextChanged: win.selected = 0

                    Label {
                        visible: !search.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: ({ apps: "Run an app", clipboard: "Search the clipboard", emoji: "Find an emoji",
                                 screenshot: "Take a screenshot", wallpaper: "Pick a wallpaper", power: "Session" })[win.mode] ?? ""
                        dim: true
                        size: Theme.fontLarge
                    }

                    Keys.onPressed: e => {
                        const n = win.items.length, cols = win.columns;
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if (e.key === Qt.Key_Escape) { win.close(); }
                        else if (e.key === Qt.Key_Tab) { win.switchMode(1); }
                        else if (e.key === Qt.Key_Backtab) { win.switchMode(-1); }
                        else if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_J)) { win.selected = Math.min(n - 1, win.selected + cols); }
                        else if (e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_K)) { win.selected = Math.max(0, win.selected - cols); }
                        else if (win.grid && e.key === Qt.Key_Right) { win.selected = Math.min(n - 1, win.selected + 1); }
                        else if (win.grid && e.key === Qt.Key_Left) { win.selected = Math.max(0, win.selected - 1); }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.activate(win.selected); }
                        else if (e.key === Qt.Key_Delete && (e.modifiers & Qt.ShiftModifier) && win.items[win.selected]?.remove) {
                            win.items[win.selected].remove();
                        }
                        else return;
                        e.accepted = true;
                    }
                }
            }

            // Mode tabs.
            Row {
                spacing: 4
                Repeater {
                    model: win.modes
                    delegate: MouseArea {
                        id: tab
                        required property var modelData
                        readonly property bool current: modelData.id === win.mode
                        width: tl.implicitWidth + 22; height: 26
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Shell.launcherMode = modelData.id; search.forceActiveFocus(); }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: tab.current ? Theme.fg : (tab.containsMouse ? Theme.hover : "transparent")
                        }
                        Label {
                            id: tl
                            anchors.centerIn: parent
                            text: tab.modelData.label
                            size: Theme.fontSmall
                            color: tab.current ? Theme.inverse : Theme.fgMuted
                            bold: tab.current
                        }
                    }
                }
            }

            // Results.
            GridView {
                id: view
                width: parent.width
                height: Math.min(contentHeight, box.parent.height * 0.7 - 120)
                cellWidth: width / win.columns
                cellHeight: win.mode === "wallpaper" ? cellWidth * 0.6 : (win.mode === "emoji" ? cellWidth : 46)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.items
                currentIndex: win.selected
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 0
                interactive: contentHeight > height

                delegate: MouseArea {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool current: index === win.selected
                    width: view.cellWidth
                    height: view.cellHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: win.selected = index
                    onClicked: win.activate(index)

                    Rectangle {
                        anchors { fill: parent; margins: 2 }
                        radius: Theme.radiusSmall
                        color: cell.current ? Theme.selected : "transparent"
                        border.width: cell.current && cell.modelData.wallpaper ? 2 : 0
                        border.color: Theme.fg
                    }

                    // Wallpaper thumbnail.
                    Image {
                        visible: !!cell.modelData.wallpaper
                        anchors { fill: parent; margins: 6 }
                        source: cell.modelData.wallpaper ? "file://" + cell.modelData.wallpaper : ""
                        sourceSize { width: 320; height: 180 }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    // Emoji.
                    Text {
                        visible: !!cell.modelData.glyphText
                        anchors.centerIn: parent
                        text: cell.modelData.glyphText || ""
                        font.pixelSize: 30
                        font.family: "Noto Color Emoji"
                    }

                    // List row.
                    Row {
                        visible: !cell.modelData.wallpaper && !cell.modelData.glyphText
                        anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 12
                        Item {
                            width: 26; height: 26
                            anchors.verticalCenter: parent.verticalCenter
                            AppIcon {
                                anchors.fill: parent
                                visible: !!cell.modelData.image
                                source: cell.modelData.image || ""
                                size: 26
                                brightness: cell.current ? 0.35 : 0.1
                            }
                            Glyph {
                                anchors.centerIn: parent
                                visible: !cell.modelData.image
                                text: cell.modelData.icon || ""
                                size: 18
                                color: cell.current ? Theme.fg : Theme.fgMuted
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            Label { width: parent.width; text: cell.modelData.title; bold: cell.current }
                            Label { width: parent.width; visible: text !== ""; text: cell.modelData.subtitle || ""; size: Theme.fontSmall; dim: true }
                        }
                    }
                }
            }

            Label {
                visible: win.items.length === 0
                width: parent.width
                height: 40
                horizontalAlignment: Text.AlignHCenter
                text: win.mode === "clipboard" ? "Clipboard history is empty" : "No match"
                dim: true
            }

            // The selected emoji's name / hints.
            Label {
                width: parent.width
                leftPadding: 4
                text: win.mode === "emoji" ? (win.items[win.selected]?.title ?? "") + "  ·  Enter copies"
                    : (win.mode === "clipboard" ? "Enter copies  ·  Shift+Del removes" : "Tab switches mode  ·  Esc closes")
                size: 10
                dim: true
            }
        }
    }
}
