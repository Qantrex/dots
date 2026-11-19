pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The whole look in one place. Colours, fonts and sizes come from the theme:
// ../theme.json links to ~/dotfiles/theme/current/quickshell.json, which
// `theme set <name>` renders (template: theme/templates/quickshell.json) and then
// calls `qs ipc call theme reload`. The defaults below are root's, so the shell
// still looks right before a theme was ever rendered.
//
// root: true-black monochrome, white/grey text and accents, never blue. Rosé Pine
// Moon colours only where they carry meaning: love = critical/error, gold =
// warning, iris = links.
Singleton {
    id: root

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // After `theme set`: for what depends on more than the colours (services/Agentic.qml).
    signal reloaded()

    // Surfaces. Translucent, so Hyprland's layer blur has something to blur.
    // bg for panels over the desktop (bar islands, popouts, OSD, notification popups),
    // bgSolid where text must stay readable over anything (launcher, tooltips).
    // The rest are fg laid over them, so they work on light themes too.
    readonly property color bgOpaque: t.bg
    readonly property color bg: withAlpha(bgOpaque, 0.85)
    readonly property color bgSolid: withAlpha(bgOpaque, 0.90)
    readonly property color border: withAlpha(fg, 0.18)
    readonly property color borderStrong: withAlpha(fg, 0.28)
    readonly property color surface: withAlpha(fg, 0.06)    // a resting card or field
    readonly property color hover: withAlpha(fg, 0.10)
    readonly property color selected: withAlpha(fg, 0.12)   // keyboard selection
    readonly property color pressed: withAlpha(fg, 0.18)
    readonly property color track: withAlpha(fg, 0.16)

    // Text.
    readonly property color fg: t.fg
    // One grey ladder, in root with this contrast against black: fgMuted 10:1,
    // fgDim 5.3:1, fgFaint for lines only.
    readonly property color fgMuted: t.fgMuted
    readonly property color fgDim: t.fgDim
    readonly property color fgFaint: t.fgFaint   // lines only, never text

    // Fills that mark "this one" (an active tile or tab, today, slider levels)
    // and what sits on them.
    readonly property color accent: t.accent
    readonly property color inverse: t.inverse             // text on an accent fill
    readonly property color inverseMuted: t.inverseMuted   // secondary text on an accent fill
    readonly property color inverseHover: withAlpha(inverse, 0.10)
    readonly property color fillHover: t.fillHover         // an accent fill under the mouse

    readonly property color love: t.love
    readonly property color gold: t.gold
    readonly property color iris: t.iris

    readonly property string font: t.font
    readonly property int fontSize: t.fontSize
    readonly property int fontSmall: t.fontSmall
    readonly property int fontLarge: t.fontLarge
    readonly property int iconSize: t.iconSize

    readonly property int barHeight: t.barHeight
    readonly property int gap: t.gap          // outer margin of the bar
    // One radius for every box (windows use the same), the small one for things inside boxes.
    readonly property int radius: t.radius
    readonly property int radiusSmall: t.radiusSmall
    readonly property int pad: t.pad

    readonly property int animFast: 140
    readonly property int anim: 220
    readonly property int animSlow: 360

    FileView {
        id: file
        path: Quickshell.shellDir + "/theme.json"
        blockLoading: true
        printErrors: false

        JsonAdapter {
            id: t
            property string bg: "#000000"
            property string fg: "#ffffff"
            property string fgMuted: "#b3b3b3"
            property string fgDim: "#808080"
            property string fgFaint: "#4d4d4d"
            property string accent: "#ffffff"
            property string inverse: "#000000"
            property string inverseMuted: "#595959"
            property string fillHover: "#d9d9d9"
            property string love: "#eb6f92"
            property string gold: "#f6c177"
            property string iris: "#c4a7e7"
            property string font: "IosevkaTerm Nerd Font"
            property int fontSize: 13
            property int fontSmall: 11
            property int fontLarge: 16
            property int iconSize: 15
            property int barHeight: 32
            property int gap: 6
            property int radius: 8
            property int radiusSmall: 4
            property int pad: 12
        }
    }

    IpcHandler {
        target: "theme"
        // `theme set` calls this after it swapped theme/current.
        function reload(): void { file.reload(); root.reloaded(); }
    }
}
