import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.services

// An app icon, turned grey to fit the monochrome look. `tint` recolours it
// completely (black on the white "active" pill).
Item {
    id: root
    property string source: ""
    property real size: 16
    property color tint: "transparent"
    property real brightness: 0.15

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: img
        anchors.fill: parent
        source: root.source
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        saturation: -1
        brightness: root.tint.a > 0 ? 0 : root.brightness
        colorization: root.tint.a > 0 ? 1 : 0
        colorizationColor: root.tint
    }
}
