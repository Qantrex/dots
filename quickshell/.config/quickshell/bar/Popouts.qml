import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components
import qs.popouts

// The popout under a bar item: a layer surface below the bar, sized to its
// panel. One at a time; a click anywhere else or Escape closes it.
PanelWindow {
    id: win
    required property var bar
    screen: bar.screen

    readonly property bool open: Shell.popout !== "" && Shell.popoutScreen === bar.screen.name
    readonly property string kind: Shell.popoutScreen === bar.screen.name ? Shell.lastPopout : ""

    visible: open || box.opacity > 0.01
    color: "transparent"
    anchors { top: true; left: true }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    margins {
        top: 6
        left: Math.round(Math.max(15, Math.min(bar.screen.width - box.width - 15, Shell.popoutX - box.width / 2)))
    }
    implicitWidth: box.width
    implicitHeight: box.height

    WlrLayershell.namespace: "qs-popout"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        windows: [win, win.bar]
        active: win.open
        onCleared: Shell.close()
    }

    Rectangle {
        id: box
        width: loader.item ? loader.item.width + 2 * Theme.pad : 0
        // Never taller than the screen below the bar; longer panels scroll.
        readonly property real maxHeight: win.bar.screen.height - Theme.barHeight - Theme.gap - 30
        height: loader.item ? Math.min(maxHeight, loader.item.implicitHeight + 2 * Theme.pad) : 0
        radius: Theme.radius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        clip: true

        NekoFrame { anchors.fill: parent; radius: parent.radius }

        opacity: win.open ? 1 : 0
        transform: Translate { y: win.open ? 0 : -8; Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: win.open; NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: win.open; NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        focus: true
        Keys.onEscapePressed: Shell.close()

        Flickable {
            anchors { fill: parent; margins: Theme.pad }
            contentWidth: width
            contentHeight: loader.item ? loader.item.implicitHeight : 0
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

        Loader {
            id: loader
            active: win.kind !== ""
            sourceComponent: ({
                control: controlC, day: dayC, media: mediaC, system: systemC,
                notifs: notifsC, tray: trayC, homelab: homelabC
            })[win.kind] ?? null
        }
        }
    }

    Component { id: controlC; ControlCenter { bar: win.bar } }
    Component { id: dayC; DayPanel {} }
    Component { id: mediaC; MediaPanel {} }
    Component { id: systemC; SystemPanel {} }
    Component { id: notifsC; NotifPanel {} }
    Component { id: trayC; TrayPanel { bar: win.bar } }
    Component { id: homelabC; HomelabPanel {} }
}
