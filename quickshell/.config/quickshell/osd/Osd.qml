import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Volume / mic / brightness indicator at the bottom of the focused screen
// (replaces swayosd). Volume changes from anywhere show it (keys, pavucontrol,
// apps); changes made inside an open control centre don't.
PanelWindow {
    id: win

    property string kind: "volume"
    property bool shown: false

    screen: Quickshell.screens.find(s => s.name === Shell.focusedScreen) ?? Quickshell.screens[0]
    visible: shown || box.opacity > 0.01
    color: "transparent"
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    margins.bottom: 80
    implicitWidth: 300
    implicitHeight: 52
    mask: Region {}                 // clicks go through

    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    function show(k) {
        if (Shell.popout === "control") return;
        kind = k;
        shown = true;
        hide.restart();
    }

    Timer { id: hide; interval: 1400; onTriggered: win.shown = false }

    // Ignore the burst of changes while PipeWire comes up.
    property bool armed: false
    Timer { interval: 2000; running: true; onTriggered: win.armed = true }

    Connections {
        target: Audio.ready ? Audio.sink.audio : null
        function onVolumeChanged() { if (win.armed) win.show("volume"); }
        function onMutedChanged() { if (win.armed) win.show("volume"); }
    }
    Connections {
        target: Audio.source && Audio.source.audio ? Audio.source.audio : null
        function onMutedChanged() { if (win.armed) win.show("mic"); }
    }
    Connections {
        target: Brightness
        function onUserChange() { win.show("brightness"); }
    }

    readonly property real value: kind === "volume" ? Audio.volume : (kind === "mic" ? Audio.micVolume : Brightness.value)
    readonly property bool off: kind === "volume" ? Audio.muted : (kind === "mic" ? Audio.micMuted : false)
    readonly property string icon: {
        if (kind === "brightness") return "󰃟";
        if (kind === "mic") return off ? "󰍭" : "󰍬";
        if (off) return "󰝟";
        return value > 0.6 ? "󰕾" : (value > 0.25 ? "󰖀" : "󰕿");
    }

    Rectangle {
        id: box
        anchors.fill: parent
        radius: height / 2
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: win.shown ? 1 : 0

        NekoFrame { anchors.fill: parent; radius: parent.radius }
        scale: win.shown ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        Row {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
            spacing: 14
            Glyph {
                id: osdIcon
                anchors.verticalCenter: parent.verticalCenter
                visible: !Neko.enabled
                width: visible ? 20 : 0
                text: win.icon
                size: 18
                color: win.off ? Theme.fgDim : Theme.fg
            }
            // nekosec: a face that follows the level instead of the icon.
            Label {
                id: osdFace
                anchors.verticalCenter: parent.verticalCenter
                visible: Neko.enabled
                width: visible ? 96 : 0
                text: win.off ? "(=×ω×=)" : win.value <= 0.001 ? "(=-ω-=)" : win.value < 0.3 ? "(=･ω･=)"
                    : win.value < 0.7 ? "(=^･ω･^=)" : win.value < 1 ? "(=ↀωↀ=)!" : "(=ↀДↀ=)!!"
                color: win.off ? Theme.fgDim : win.value >= 1 ? Theme.love : Theme.accent
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (Neko.enabled ? osdFace.width : osdIcon.width) - 44 - 2 * parent.spacing
                height: 6; radius: 3
                color: Theme.track
                Rectangle {
                    width: parent.width * Math.min(1, win.value)
                    height: parent.height; radius: 3
                    color: win.off ? Theme.fgDim : Theme.accent
                    gradient: Neko.enabled && !win.off ? nekoFill : null
                    Gradient {
                        id: nekoFill
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 0.6; color: Neko.lilac }
                        GradientStop { position: 1; color: Neko.mint }
                    }
                    Behavior on width { NumberAnimation { duration: Theme.animFast } }
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: win.off ? "off" : Math.round(win.value * 100)
                size: Theme.fontSmall + 1
                color: win.off ? Theme.fgDim : Theme.fg
            }
        }
    }
}
