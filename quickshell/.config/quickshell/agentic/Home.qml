import QtQuick
import qs.services
import qs.components

// The home tab of the agent panel: the login brief and the inbox (`agentic brief`, `inbox`).
// Looking at it marks the inbox as seen, which clears the number on the tab.
Flickable {
    id: root
    contentHeight: col.implicitHeight + 2 * Theme.pad
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function tint(level) {
        return level === "broke" ? Theme.love : (level === "needs" ? Theme.gold : (level === "done" ? Theme.fg : Theme.fgMuted));
    }

    Column {
        id: col
        x: Theme.pad
        y: Theme.pad
        width: root.width - 2 * Theme.pad
        spacing: 6

        SectionTitle { width: parent.width; text: "Brief" }
        Repeater {
            model: Agentic.brief
            Label {
                required property string modelData
                width: col.width
                leftPadding: 4
                text: modelData
                size: Agentic.fontSize
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                lineHeight: 1.25
            }
        }
        Label { visible: Agentic.brief.length === 0; leftPadding: 4; text: "Nothing to report."; dim: true; size: Agentic.fontSize }

        Item { width: 1; height: 10 }
        SectionTitle { width: parent.width; text: "Inbox" }
        Repeater {
            model: Agentic.inbox
            Item {
                id: row
                required property var modelData
                width: col.width
                implicitHeight: Math.max(20, what.implicitHeight) + 8

                Rectangle {
                    visible: row.modelData.new === true
                    anchors { left: parent.left; top: parent.top; topMargin: 11 }
                    width: 5; height: 5; radius: 2.5
                    color: Theme.fg
                }
                Label {
                    id: when
                    anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 4 }
                    width: Math.round(44 * Agentic.fontSmall / Theme.fontSmall)
                    text: row.modelData.at || ""
                    dim: true
                    size: Agentic.fontSmall
                }
                Label {
                    id: who
                    anchors { left: when.right; top: parent.top; topMargin: 4 }
                    width: Math.round(76 * Agentic.fontSmall / Theme.fontSmall)
                    text: row.modelData.source || ""
                    size: Agentic.fontSmall
                    color: root.tint(row.modelData.level)
                }
                Label {
                    id: what
                    anchors { left: who.right; leftMargin: 6; right: parent.right; top: parent.top; topMargin: 3 }
                    text: row.modelData.text || ""
                    size: Agentic.fontSize
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    verticalAlignment: Text.AlignTop
                    color: row.modelData.level === "info" ? Theme.fgMuted : Theme.fg
                }
            }
        }
        Label { visible: Agentic.inbox.length === 0; leftPadding: 4; text: "The inbox is empty."; dim: true; size: Agentic.fontSize }
    }
}
