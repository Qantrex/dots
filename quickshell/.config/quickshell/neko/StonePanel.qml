import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// nekosec: what you see when you look into the seeing stone (click it on the
// wallpaper, or `qs ipc call neko stone`). What the stone is, who is watching
// right now, and the current picture. Esc or a click outside closes it.
PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === Shell.focusedScreen) ?? Quickshell.screens[0]
    visible: Neko.stoneOpen || box.opacity > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "qs-launcher"   // blurred like the launcher's box
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Neko.stoneOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() { Neko.stoneOpen = false; }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: Neko.stoneOpen ? 0.35 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        }
    }

    Rectangle {
        id: box
        width: 640
        height: col.implicitHeight + 2 * 26
        anchors.centerIn: parent
        radius: Theme.radius
        color: Theme.bgSolid
        border.width: 1
        border.color: Theme.borderStrong
        opacity: Neko.stoneOpen ? 1 : 0
        scale: Neko.stoneOpen ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
        focus: true
        Keys.onEscapePressed: win.close()

        MouseArea { anchors.fill: parent }   // clicks inside don't close it
        NekoFrame { anchors.fill: parent; radius: parent.radius; ears: true; earWidth: 34; earHeight: 20 }

        Column {
            id: col
            x: 26; y: 26
            width: parent.width - 52
            spacing: 14

            Row {
                spacing: 16
                // the stone itself, small: a slit-pupil eye
                Rectangle {
                    width: 54; height: 54; radius: 27
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 0.6; color: "#8a3fd1" }
                        GradientStop { position: 1; color: Theme.bgOpaque }
                    }
                    border.width: 2; border.color: Theme.accent
                    Rectangle {
                        id: pupil
                        anchors.centerIn: parent
                        width: 6; height: 40; radius: 3
                        color: Theme.bgOpaque
                        // it blinks now and then
                        SequentialAnimation on height {
                            running: Neko.stoneOpen
                            loops: Animation.Infinite
                            PauseAnimation { duration: 2600 }
                            NumberAnimation { to: 4; duration: 90 }
                            NumberAnimation { to: 40; duration: 140 }
                        }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Label { text: "THE SEEING STONE  (=ↀωↀ=)"; bold: true; size: Theme.fontLarge; color: Theme.accent }
                    Label { text: "a palantír with cat ears · it looks back"; dim: true; size: Theme.fontSmall }
                }
            }

            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.fgMuted
                text: "In Lord of the Rings a palantír is a seeing stone: look into it and you see far-away things, " +
                      "but whoever holds another stone can look back at you. A big-data surveillance company named " +
                      "itself after it. In nekosec the stone is a cat's eye on your wallpaper, the theme's joke about " +
                      "being watched, and it does watch something real: what on this machine could be watching you."
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Label { text: "WHO IS WATCHING RIGHT NOW"; bold: true; size: Theme.fontSmall; color: Neko.lilac }
            Grid {
                columns: 2
                columnSpacing: 18
                rowSpacing: 8
                Label { text: "firewall"; dim: true }
                Label { text: Neko.firewall ? "on (nftables loaded this boot)" : "OFF"; color: Neko.firewall ? Neko.mint : Theme.love }
                Label { text: "tunnel"; dim: true }
                Label {
                    text: (Neko.vpn.length ? "VPN " + Neko.vpn.join(", ") : "no VPN") + (Neko.tor ? " · Tor running" : "")
                    color: (Neko.vpn.length || Neko.tor) ? Neko.mint : Theme.fgMuted
                }
                Label { text: "cameras"; dim: true }
                Label {
                    text: Neko.cams ? Neko.camApps.join(", ") + " (" + Neko.cams + ")" : "none in use"
                    color: Neko.cams ? Theme.love : Neko.mint
                }
                Label { text: "microphones"; dim: true }
                Label {
                    text: Neko.mics ? Neko.micApps.join(", ") + " (" + Neko.mics + ")" : "none in use"
                    color: Neko.mics ? Theme.love : Neko.mint
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Label { text: "IN THE STONE"; bold: true; size: Theme.fontSmall; color: Neko.lilac }
            Row {
                spacing: 14
                Image {
                    width: 64; height: 64
                    source: Neko.avatar ? "file://" + Neko.avatar + "?v=" + Neko.version : ""
                    cache: false
                    smooth: true; mipmap: true
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Label { text: (Neko.subject ? "agent " + Neko.subject : "nobody yet") + (Neko.threat ? " · threat: " + Neko.threat : "") }
                    Label { text: (Neko.artist ? "art: " + Neko.artist : "artist unknown") + " · mode " + Neko.mode + (Neko.paused ? " · paused" : ""); dim: true; size: Theme.fontSmall }
                }
            }

            Row {
                spacing: 8
                Repeater {
                    model: [
                        { label: "next picture", run: () => Neko.next() },
                        { label: Neko.paused ? "resume" : "pause", run: () => Neko.togglePause() },
                        { label: "save", run: () => Neko.save() },
                        { label: "open page", run: () => Neko.openPage() }
                    ]
                    delegate: MouseArea {
                        id: btn
                        required property var modelData
                        width: bl.implicitWidth + 24; height: 30
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { modelData.run(); Qt.callLater(Neko.refresh); }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: btn.containsMouse ? Theme.accent : Theme.surface
                            border.width: 1; border.color: Theme.border
                            NekoFrame { anchors.fill: parent; frame: false; ears: true; earWidth: 8; earHeight: 6; earInset: 3; visible: btn.containsMouse }
                        }
                        Label { id: bl; anchors.centerIn: parent; text: btn.modelData.label; size: Theme.fontSmall; color: btn.containsMouse ? Theme.inverse : Theme.fg }
                    }
                }
            }
        }
    }
}
