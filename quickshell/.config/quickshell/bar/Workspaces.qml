import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.components

// Occupied workspaces of this screen, each shown as the icons of its apps
// (up to three). The active one sits on a light grey pill with its icons at full
// strength, the others are dimmed; urgent ones pulse. (A white pill turned the icons
// into black silhouettes, and filled icons like foot's became plain squares.)
Island {
    id: root
    required property var bar
    readonly property string screenName: bar.screen.name

    padding: 4
    spacing: 2

    // Workspaces on this monitor that have windows or are active; plus the
    // special workspace while it has windows.
    readonly property var list: Hyprland.workspaces.values
        .filter(w => w.id > 0 && (!w.monitor || w.monitor.name === screenName)
                && (w.toplevels.values.length > 0 || w.active || w.focused))
        .sort((a, b) => a.id - b.id)
    readonly property var special: Hyprland.workspaces.values
        .find(w => w.id < 0 && w.name === "special:magic" && w.toplevels.values.length > 0) ?? null

    Repeater {
        model: root.list
        delegate: MouseArea {
            id: ws
            required property var modelData
            readonly property bool active: modelData.active && modelData.monitor?.name === root.screenName
            readonly property var apps: {
                const seen = [];
                for (const t of modelData.toplevels.values) {
                    const id = t.wayland?.appId || t.lastIpcObject?.class || "";
                    if (id && !seen.includes(id)) seen.push(id);
                }
                return seen.slice(0, 3);
            }

            implicitWidth: Math.max(Theme.barHeight - 8, content.implicitWidth + (active ? 22 : 14))
            implicitHeight: Theme.barHeight - 8
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: modelData.activate()
            // The config is Lua, so dispatches are Lua too (`workspace e+1` fails).
            onWheel: w => Hyprland.dispatch('hl.dsp.focus({ workspace = "' + (w.angleDelta.y > 0 ? "e-1" : "e+1") + '" })')

            Behavior on implicitWidth { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutQuint } }

            Tooltip {
                target: ws
                show: ws.containsMouse
                // Each screen counts its own 1–10 (hypr/lua/workspaces.lua): 14 is the side screen's 4.
                text: "Workspace " + ((ws.modelData.id - 1) % 10 + 1) + "\n"
                      + ws.modelData.toplevels.values.map(t => "· " + (t.title || t.wayland?.appId || "")).join("\n")
            }

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: ws.active ? Theme.pressed : (ws.containsMouse ? Theme.hover : "transparent")
                border.width: ws.modelData.urgent && !ws.active ? 1 : 0
                border.color: Theme.fg
                Behavior on color { ColorAnimation { duration: Theme.anim } }

                SequentialAnimation on opacity {
                    running: ws.modelData.urgent && !ws.active
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
            }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 5

                Repeater {
                    model: ws.apps
                    delegate: Item {
                        required property string modelData
                        readonly property string iconPath: {
                            const e = DesktopEntries.heuristicLookup(modelData);
                            return Quickshell.iconPath(e?.icon || modelData.toLowerCase(), true);
                        }
                        implicitWidth: 16
                        implicitHeight: 16
                        AppIcon {
                            anchors.fill: parent
                            visible: parent.iconPath !== ""
                            source: parent.iconPath
                            opacity: ws.active ? 1 : (ws.containsMouse ? 0.85 : 0.55)
                            brightness: ws.active ? 0.25 : 0.1
                        }
                        Glyph {
                            anchors.centerIn: parent
                            visible: parent.iconPath === ""
                            text: "󰣆"
                            size: 14
                            color: ws.active ? Theme.fg : Theme.fgMuted
                        }
                    }
                }
                // Empty but active: the number.
                Label {
                    visible: ws.apps.length === 0
                    text: ws.modelData.name
                    bold: ws.active
                    color: ws.active ? Theme.fg : Theme.fgMuted
                }
            }
        }
    }

    // The scratchpad (SUPER+S) while it holds windows.
    BarItem {
        visible: root.special !== null
        hpad: 6
        tip: "Scratchpad (SUPER+S)"
        onLeftClicked: Hyprland.dispatch('hl.dsp.workspace.toggle_special("magic")')
        Glyph { text: "󰐃"; color: Theme.fgMuted; size: 13 }
    }
}
