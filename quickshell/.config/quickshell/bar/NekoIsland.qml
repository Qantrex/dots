import QtQuick
import Quickshell
import qs.services
import qs.components

// nekosec only (services/Neko.qml): the current catgirl as a round avatar, her mood,
// and an opsec line: firewall, VPN or Tor, and how many cameras and microphones
// are in use ("watched by").
//   Left: next picture · Middle: save it to ~/Downloads · Right: open its page
//   Scroll: pause / resume the changing
// The NSFW switch stays on the command line (`neko mode`), never on a click.
Island {
    id: root
    required property var bar
    visible: Neko.enabled
    padding: 4
    spacing: 2

    BarItem {
        id: face
        hpad: 6
        spacing: 7
        onLeftClicked: Neko.next()
        onMiddleClicked: Neko.save()
        onRightClicked: Neko.openPage()
        onScrolled: Neko.togglePause()
        tip: (Neko.subject ? Neko.subject + " · " : "") + (Neko.artist ? "art: " + Neko.artist : "artist unknown")
             + (Neko.threat ? "\nthreat level: " + Neko.threat : "")
             + "\nmode " + Neko.mode + (Neko.paused ? " · paused" : "")
             + "\nLeft: next · Middle: save · Right: open page · Scroll: pause"

        Item {
            width: 24; height: 24
            anchors.verticalCenter: parent.verticalCenter
            Image {
                id: av
                anchors.fill: parent
                source: Neko.avatar ? "file://" + Neko.avatar + "?v=" + Neko.version : ""
                cache: false
                asynchronous: true
                smooth: true
                mipmap: true
                fillMode: Image.PreserveAspectFit
                opacity: Neko.paused ? 0.45 : 1
                // A little hop on every new picture.
                onStatusChanged: if (status === Image.Ready) hop.restart()
                SequentialAnimation on y {
                    id: hop
                    running: false
                    NumberAnimation { to: -5; duration: 120; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 0; duration: 380; easing.type: Easing.OutBounce }
                }
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Neko.paused ? "(=-ω-=) zzz" : Neko.kaomoji
            color: Neko.mode === "sfw" ? Theme.accent : Theme.love
        }
    }

    Rectangle {
        width: 1; height: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.border
    }

    BarItem {
        hpad: 6
        spacing: 8
        tip: "firewall " + (Neko.firewall ? "on" : "OFF")
             + "\n" + (Neko.vpn.length ? "VPN " + Neko.vpn.join(", ") : "no VPN") + (Neko.tor ? " · Tor running" : "")
             + "\nwatched by: " + Neko.cams + " camera" + (Neko.cams === 1 ? "" : "s")
             + ", " + Neko.mics + " microphone" + (Neko.mics === 1 ? "" : "s")
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Neko.firewall ? "󰒃" : "󰦞"
            size: 13
            color: Neko.firewall ? Theme.fgMuted : Theme.love
        }
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Neko.tor ? "󰗹" : "󰖂"
            size: 13
            color: (Neko.vpn.length || Neko.tor) ? Theme.fgMuted : Theme.fgDim
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Neko.watchers > 0 ? "󰈈" : "󰈉"
                size: 13
                color: Neko.watchers > 0 ? Theme.love : Theme.fgDim
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Neko.watchers > 0
                text: Neko.watchers
                color: Theme.love
                size: Theme.fontSmall
            }
        }
    }
}
