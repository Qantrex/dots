import QtQuick
import qs.services

// A Nerd Font icon.
Text {
    property real size: Theme.iconSize
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: size
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
}
