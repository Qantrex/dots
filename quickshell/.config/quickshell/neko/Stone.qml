import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// nekosec only: the seeing stone on the wallpaper, made clickable.
// A wallpaper takes no clicks, so a small layer sits exactly over the stone, under
// every window (layer Bottom): it only answers where the desktop shows. The daemon
// writes where the stone is (state.json "stone", in wallpaper pixels): the big cat
// stone on the theme's own wallpaper, or the small eye on each catgirl feed.
//   Left click: look into the stone (StonePanel) · Right click: the next picture
Scope {
    id: root
    required property var modelData

    // Hyprpaper fills the screen ("cover"): map wallpaper pixels to screen points.
    readonly property var st: Neko.stone
    readonly property real sw: modelData.width
    readonly property real sh: modelData.height
    readonly property real k: st ? Math.max(sw / st.w, sh / st.h) : 1
    readonly property real cx: st ? (sw - st.w * k) / 2 + st.cx * k : 0
    readonly property real cy: st ? (sh - st.h * k) / 2 + st.cy * k : 0
    readonly property real r: st ? st.r * k : 0

    PanelWindow {
        id: spot
        screen: root.modelData
        visible: root.st !== null && root.r > 4
        anchors { left: true; top: true }
        margins { left: Math.round(root.cx - root.r); top: Math.round(root.cy - root.r) }
        implicitWidth: Math.round(root.r * 2)
        implicitHeight: Math.round(root.r * 2)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "qs-neko-stone"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // only inside the circle
            readonly property bool inside: Math.hypot(mouseX - width / 2, mouseY - height / 2) <= width / 2
            cursorShape: inside ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: m => {
                if (!inside) return;
                if (m.button === Qt.RightButton) Neko.next();
                else { Neko.stoneOpen = !Neko.stoneOpen; Neko.refresh(); }
            }

            // A glow ring while the pointer is on the stone.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: width; radius: width / 2
                color: "transparent"
                border.width: area.inside && area.containsMouse ? 3 : 0
                border.color: Theme.accent
                opacity: area.inside && area.containsMouse ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                SequentialAnimation on scale {
                    running: area.containsMouse && area.inside
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.04; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
