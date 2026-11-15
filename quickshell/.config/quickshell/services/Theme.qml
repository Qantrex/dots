pragma Singleton

import QtQuick
import Quickshell

// The whole look in one place: true-black monochrome, white/grey text and
// accents, never blue. Rosé Pine Moon colours only where they carry meaning:
// love = critical/error, gold = warning, iris = links.
Singleton {
    // Surfaces. Translucent, so Hyprland's layer blur has something to blur.
    // bg for panels over the desktop (bar islands, popouts, OSD, notification popups),
    // bgSolid where text must stay readable over anything (launcher, tooltips).
    readonly property color bg: Qt.rgba(0, 0, 0, 0.85)
    readonly property color bgSolid: Qt.rgba(0, 0, 0, 0.90)
    readonly property color border: Qt.rgba(1, 1, 1, 0.18)
    readonly property color borderStrong: Qt.rgba(1, 1, 1, 0.28)
    readonly property color surface: Qt.rgba(1, 1, 1, 0.06)    // a resting card or field
    readonly property color hover: Qt.rgba(1, 1, 1, 0.10)
    readonly property color selected: Qt.rgba(1, 1, 1, 0.12)   // keyboard selection
    readonly property color pressed: Qt.rgba(1, 1, 1, 0.18)
    readonly property color track: Qt.rgba(1, 1, 1, 0.16)

    // Text.
    readonly property color fg: "#ffffff"
    // One grey ladder, contrast against black: fgMuted 10:1, fgDim 5.3:1, fgFaint for lines only.
    readonly property color fgMuted: "#b3b3b3"
    readonly property color fgDim: "#808080"
    readonly property color fgFaint: "#4d4d4d"   // lines only, never text
    readonly property color inverse: "#000000"   // text on a white fill
    readonly property color inverseMuted: "#595959"           // secondary text on a white fill
    readonly property color inverseHover: Qt.rgba(0, 0, 0, 0.10)
    readonly property color fillHover: "#d9d9d9"              // a white fill under the mouse

    // Rosé Pine Moon, sparingly.
    readonly property color love: "#eb6f92"
    readonly property color gold: "#f6c177"
    readonly property color iris: "#c4a7e7"

    readonly property string font: "IosevkaTerm Nerd Font"
    readonly property int fontSize: 13
    readonly property int fontSmall: 11
    readonly property int fontLarge: 16
    readonly property int iconSize: 15

    readonly property int barHeight: 32
    readonly property int gap: 6          // outer margin of the bar
    // One radius for every box (windows use 8 too), the small one for things inside boxes.
    readonly property int radius: 8
    readonly property int radiusSmall: 4
    readonly property int pad: 12

    readonly property int animFast: 140
    readonly property int anim: 220
    readonly property int animSlow: 360
}
