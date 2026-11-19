import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Notification popups, top right under the bar, on the focused screen.
// Hovering one pauses its timer. Timers count from when the popup was shown (Notifs.remaining),
// because the Repeater rebuilds every card whenever the list changes.
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Shell.focusedScreen) ?? Quickshell.screens[0]
    visible: Notifs.popups.length > 0 || col.implicitHeight > 0
    color: "transparent"
    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    margins { top: 6; right: 15 }
    implicitWidth: 440
    // nekosec: room above each card for its cat ears
    readonly property int earRoom: Neko.enabled ? 14 : 0
    implicitHeight: Math.max(1, col.implicitHeight + earRoom)

    WlrLayershell.namespace: "qs-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: col
        y: win.earRoom
        width: parent.width
        spacing: 8 + win.earRoom

        Repeater {
            model: Notifs.popups
            delegate: Item {
                id: slot
                required property var modelData
                width: col.width
                implicitHeight: card.implicitHeight

                NotifCard {
                    id: card
                    width: parent.width
                    notif: slot.modelData
                    popup: true
                    onCloseRequested: Notifs.dismissPopup(slot.modelData)

                    opacity: 0
                    x: 40
                    Component.onCompleted: { opacity = 1; x = 0; }
                    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                    Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

                    // Leaving a card gives it its full time again.
                    HoverHandler {
                        id: hover
                        onHoveredChanged: if (!hovered) { Notifs.touch(slot.modelData); timer.interval = Math.max(1, Notifs.timeoutFor(slot.modelData)); }
                    }
                }

                Timer {
                    id: timer
                    interval: Notifs.remaining(slot.modelData)
                    running: Notifs.timeoutFor(slot.modelData) > 0 && !hover.hovered
                    onTriggered: Notifs.dismissPopup(slot.modelData)
                }
            }
        }
    }
}
