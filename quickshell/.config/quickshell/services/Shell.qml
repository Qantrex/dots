pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// UI state shared by all screens, and the IPC entry points that the keybinds
// and scripts use (`qs ipc show` lists them).
Singleton {
    id: root

    // One popout at a time, on one screen, under one bar item.
    property string popout: ""            // "", control, day, media, system, notifs, tray, homelab
    property string popoutScreen: ""
    property real popoutX: 0              // centre of the bar item, in screen coordinates
    property string lastPopout: ""        // kept while the closing animation runs

    // The launcher (apps, clipboard, emoji, screenshot, wallpaper, power).
    property bool launcherOpen: false
    property string launcherMode: "apps"

    // Keeps the screen awake (idle inhibitor on the bar).
    property bool caffeine: persist.caffeine
    function setCaffeine(on) { persist.caffeine = on; }

    PersistentProperties {
        id: persist
        reloadableId: "shell"
        property bool caffeine: false
    }

    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? ""

    function toggle(kind, screen, x) {
        if (popout === kind && popoutScreen === screen) { close(); return; }
        popoutX = x;
        popoutScreen = screen;
        lastPopout = kind;
        popout = kind;
        launcherOpen = false;
    }
    function close() { popout = ""; }

    function openLauncher(mode) {
        close();
        launcherMode = mode || "apps";
        launcherOpen = true;
    }
    function toggleLauncher(mode) {
        if (launcherOpen && launcherMode === (mode || "apps")) launcherOpen = false;
        else openLauncher(mode);
    }

    IpcHandler {
        target: "bar"
        // Scripts call this after they change something: vault, touchpad, powerprofile, ai ("" = all).
        function refresh(name: string): void { Scripts.refresh(name); }
        // Opens a popout on the focused screen, centred: control, day, media, system, notifs, homelab.
        function popout(kind: string): void {
            const s = Quickshell.screens.find(x => x.name === root.focusedScreen) ?? Quickshell.screens[0];
            root.toggle(kind, s.name, s.width - 200);
        }
        function close(): void { root.close(); }
    }

    IpcHandler {
        target: "launcher"
        // Modes: apps, clipboard, emoji, screenshot, wallpaper, power.
        function toggle(mode: string): void { root.toggleLauncher(mode); }
        function open(mode: string): void { root.openLauncher(mode); }
        function close(): void { root.launcherOpen = false; }
    }

    IpcHandler {
        target: "osd"
        // Called by the brightness keys after brightnessctl.
        function brightness(): void { Brightness.refresh(true); }
    }

    IpcHandler {
        target: "notifs"
        function dnd(): void { Notifs.setDnd(!Notifs.dnd); }
        function clear(): void { Notifs.clearAll(); }
    }

    IpcHandler {
        target: "caffeine"
        function toggle(): void { root.setCaffeine(!root.caffeine); }
    }
}
