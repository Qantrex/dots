import QtQuick
import qs.services

Text {
    property bool muted: false
    property bool dim: false
    property bool bold: false
    property real size: Theme.fontSize
    color: dim ? Theme.fgDim : (muted ? Theme.fgMuted : Theme.fg)
    font.family: Theme.font
    font.pixelSize: size
    font.weight: bold ? Font.Bold : Font.Medium
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}
