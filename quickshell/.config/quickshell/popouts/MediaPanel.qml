import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.services
import qs.components

// Now playing: cover (in greyscale), seek bar, controls, and the other players.
Column {
    id: root
    width: 360
    spacing: 12

    readonly property var p: Media.player

    // MPRIS only reports the position when asked.
    Timer {
        interval: 1000
        running: !!root.p && root.p.isPlaying
        repeat: true
        triggeredOnStart: true
        onTriggered: if (root.p) root.p.positionChanged()
    }

    Row {
        width: parent.width
        spacing: 14

        Rectangle {
            id: cover
            width: 96; height: 96
            radius: Theme.radiusSmall
            color: Theme.surface
            clip: true
            Image {
                id: art
                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
                sourceSize { width: 192; height: 192 }
            }
            MultiEffect {
                anchors.fill: parent
                source: art
                visible: art.status === Image.Ready
                saturation: -1
                contrast: 0.1
            }
            Glyph { anchors.centerIn: parent; visible: art.status !== Image.Ready; text: "󰎆"; size: 32; color: Theme.fgDim }
        }

        Column {
            width: parent.width - cover.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Label { width: parent.width; text: Media.title || "Nothing playing"; bold: true; size: Theme.fontLarge - 1; wrapMode: Text.WordWrap; maximumLineCount: 2 }
            Label { width: parent.width; text: Media.artist; muted: true }
            Label { width: parent.width; text: root.p ? root.p.trackAlbum : ""; dim: true; size: Theme.fontSmall }
        }
    }

    // Seek bar.
    Column {
        width: parent.width
        visible: !!root.p && root.p.lengthSupported && root.p.length > 0
        spacing: 2
        Item {
            width: parent.width
            height: 14
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                color: Theme.track
                Rectangle {
                    width: root.p && root.p.length > 0 ? parent.width * Math.min(1, root.p.position / root.p.length) : 0
                    height: parent.height; radius: 2
                    color: Theme.accent
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !!root.p && root.p.canSeek
                cursorShape: Qt.PointingHandCursor
                onClicked: m => root.p.position = root.p.length * m.x / width
            }
        }
        Item {
            width: parent.width
            height: 14
            Label { text: Media.fmt(root.p ? root.p.position : 0); size: 10; dim: true }
            Label { anchors.right: parent.right; text: Media.fmt(root.p ? root.p.length : 0); size: 10; dim: true }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.p && root.p.shuffleSupported
            icon: "󰒟"
            iconColor: root.p && root.p.shuffle ? Theme.fg : Theme.fgDim
            onClicked: root.p.shuffle = !root.p.shuffle
        }
        IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "󰒮"; size: 36; iconSize: 18; onClicked: Media.previous() }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Media.active ? "󰏤" : "󰐊"
            size: 44; iconSize: 22
            filled: true
            onClicked: Media.toggle()
        }
        IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "󰒭"; size: 36; iconSize: 18; onClicked: Media.next() }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.p && root.p.loopSupported
            icon: root.p && root.p.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
            iconColor: root.p && root.p.loopState !== MprisLoopState.None ? Theme.fg : Theme.fgDim
            onClicked: root.p.loopState = root.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                        : (root.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
        }
    }

    // Other players: click to bring their window up.
    Column {
        width: parent.width
        visible: Media.players.length > 1
        spacing: 1
        SectionTitle { width: parent.width; text: "Players" }
        Repeater {
            model: Media.players
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: modelData.isPlaying ? "󰐊" : "󰏤"
                title: modelData.identity
                subtitle: modelData.trackTitle || ""
                highlighted: modelData === root.p
                onClicked: { Media.lastActive = modelData; if (modelData.canRaise) modelData.raise(); }
            }
        }
    }
}
