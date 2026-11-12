pragma Singleton

import QtQuick
import Quickshell

// The whole look in one place: true-black monochrome, white/grey text and
// accents, never blue. Rosé Pine Moon colours only where they carry meaning:
// love = critical/error, gold = warning, iris = links.
Singleton {
    // Surfaces. Translucent, so Hyprland's layer blur has something to blur.
    readonly property color bg: Qt.rgba(0, 0, 0, 0.62)
    readonly property color bgSolid: Qt.rgba(0, 0, 0, 0.88)
    readonly property color border: Qt.rgba(1, 1, 1, 0.12)
    readonly property color borderStrong: Qt.rgba(1, 1, 1, 0.28)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.10)
    readonly property color pressed: Qt.rgba(1, 1, 1, 0.18)
    readonly property color track: Qt.rgba(1, 1, 1, 0.16)

    // Text.
    readonly property color fg: "#ffffff"
    readonly property color fgMuted: Qt.rgba(1, 1, 1, 0.62)
    readonly property color fgDim: Qt.rgba(1, 1, 1, 0.40)
    readonly property color inverse: "#000000"   // text on a white fill

    // Rosé Pine Moon, sparingly.
    readonly property color love: "#eb6f92"
    readonly property color gold: "#f6c177"
    readonly property color iris: "#c4a7e7"

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int fontSmall: 11
    readonly property int fontLarge: 16
    readonly property int iconSize: 15

    readonly property int barHeight: 32
    readonly property int gap: 6          // outer margin of the bar
    readonly property int radius: 10
    readonly property int radiusSmall: 7
    readonly property int pad: 12

    readonly property int animFast: 140
    readonly property int anim: 220
    readonly property int animSlow: 360
}
