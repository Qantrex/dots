import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// One bar per screen: three floating islands.
//   left    workspaces (app icons); in nekosec the catgirl island before them
//   centre  clock (+ an urgent deadline), media while playing
//   right   exceptions (only what needs attention) | status cluster | tray
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // Hyprland's gaps_out is 15: the islands line up with the window edges.
    readonly property int side: 15

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight + Theme.gap
    exclusiveZone: implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Caffeine: keeps swayidle (and with it dim, lock, suspend) away.
    IdleInhibitor {
        window: bar
        enabled: Shell.caffeine
    }

    // Opens a popout under `item`.
    function pop(kind, item) {
        const p = item.mapToItem(null, item.width / 2, 0);
        Shell.toggle(kind, bar.screen.name, p.x);
    }
    function isOpen(kind) { return Shell.popout === kind && Shell.popoutScreen === bar.screen.name; }

    Row {
        anchors { left: parent.left; leftMargin: bar.side; top: parent.top; topMargin: Theme.gap }
        spacing: 8
        NekoIsland { bar: bar }   // nekosec only; invisible (and takes no room) otherwise
        Workspaces { bar: bar }
    }

    Center {
        bar: bar
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.gap }
    }

    Row {
        anchors { right: parent.right; rightMargin: bar.side; top: parent.top; topMargin: Theme.gap }
        spacing: 8
        Exceptions { bar: bar }
        Status { bar: bar }
    }
}
