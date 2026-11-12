import QtQuick
import Quickshell
import qs.services

// A tooltip under `target` after a short hover. The bar is icons only, so every
// icon explains itself (what it is, what the clicks do).
Item {
    id: root
    required property Item target
    property string text: ""
    property bool show: false
    property int delay: 450

    visible: false
    property bool shown: false
    onShowChanged: show && text !== "" ? timer.restart() : (timer.stop(), shown = false)

    Timer { id: timer; interval: root.delay; onTriggered: root.shown = true }

    LazyLoader {
        active: root.shown && root.text !== ""
        PopupWindow {
            // Top-left corner at this point of the target: centred, 8 px below.
            anchor.item: root.target
            anchor.rect.y: root.target.height + 8
            anchor.rect.x: root.target.width / 2 - implicitWidth / 2
            anchor.adjustment: PopupAdjustment.SlideX
            implicitWidth: box.width
            implicitHeight: box.height
            color: "transparent"
            visible: true

            Rectangle {
                id: box
                width: Math.min(label.implicitWidth, 360) + 20
                height: label.implicitHeight + 12
                radius: Theme.radiusSmall
                color: Qt.rgba(0, 0, 0, 0.92)
                border.width: 1
                border.color: Theme.borderStrong

                Text {
                    id: label
                    x: 10
                    y: 6
                    width: Math.min(implicitWidth, 360)
                    text: root.text
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSmall + 1
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
