import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// The agent panel (theme root-agentic): the main Claude chat, its threads and the home tab on
// the right edge, about 40 % wide, over the windows and under the bar. shell.qml loads it only
// while Agentic.enabled, and it is a layer surface only while it is open.
//
// Keys: Esc hides it, Ctrl+Tab and Ctrl+Shift+Tab change the tab, Ctrl+T opens the real Claude
// Code terminal of the tab (also the button on the top right).
PanelWindow {
    id: win

    readonly property bool open: Agentic.open
    // The screen it opened on; it does not follow the focus to another one while open.
    property string shownOn: Shell.focusedScreen
    readonly property int edge: 15    // the windows' outer gap (gaps_out) and the bar's side margin

    screen: Quickshell.screens.find(s => s.name === shownOn) ?? Quickshell.screens[0]
    visible: open || box.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; right: true }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    margins { top: Theme.gap; right: edge; bottom: edge }
    implicitWidth: Math.round(Math.min(screen.width - 2 * edge, Math.max(Agentic.minWidth, screen.width * Agentic.widthShare)))

    WlrLayershell.namespace: "qs-agentic"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open && !Quickshell.env("QS_AGENTIC_NOFOCUS") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: if (open) { shownOn = Shell.focusedScreen; if (backingWindowVisible) body.takeFocus(); }
    // The window exists only while it is visible, and a focus set before that is lost.
    onBackingWindowVisibleChanged: if (backingWindowVisible && open) body.takeFocus()

    Rectangle {
        id: box
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bgOpaque
        border.width: 1
        border.color: Theme.border
        clip: true

        opacity: win.open ? 1 : 0
        transform: Translate { x: win.open ? 0 : 24; Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        FocusScope {
            id: body
            anchors.fill: parent
            focus: true

            function takeFocus() {
                body.forceActiveFocus();
                if (chats.count > 0 && chats.itemAt(0)) chats.itemAt(0).takeFocus();
            }

            Keys.onPressed: e => Agentic.key(e)


            // Tabs on the left, the terminal and close buttons on the right.
            Item {
                id: head
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.pad - 4 }
                height: 32

                Flickable {
                    anchors { left: parent.left; right: tools.left; rightMargin: 8; top: parent.top; bottom: parent.bottom }
                    contentWidth: tabRow.implicitWidth
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: tabRow
                        height: parent.height
                        spacing: 4
                        Repeater {
                            model: Agentic.tabs
                            Tab {
                                required property string modelData
                                name: modelData
                                height: tabRow.height
                            }
                        }
                    }
                }
                Row {
                    id: tools
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    IconButton {
                        id: term
                        icon: "󰆍"
                        onClicked: Agentic.terminal()
                        Tooltip { target: term; show: term.containsMouse; text: "The Claude Code terminal of this tab (Ctrl+T)" }
                    }
                    IconButton {
                        icon: "󰅖"
                        onClicked: Agentic.hide()
                    }
                }
            }
            Rectangle {
                id: rule
                anchors { top: head.bottom; topMargin: Theme.pad - 4; left: parent.left; right: parent.right }
                height: 1
                color: Theme.border
            }

            Item {
                id: page
                anchors { top: rule.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

                // One conversation view per tab: a tab change drops the old one with its feed
                // process and starts a new one.
                Repeater {
                    id: chats
                    model: Agentic.target !== "home" ? [Agentic.target] : []
                    onItemAdded: (i, item) => { if (win.open) item.takeFocus(); }
                    Chat {
                        required property string modelData
                        target: modelData
                        anchors.fill: parent
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: Agentic.target === "home"
                    sourceComponent: Home {}
                }
            }
        }
    }
}
