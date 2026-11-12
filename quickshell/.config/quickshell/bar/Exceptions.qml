import QtQuick
import Quickshell
import qs.services
import qs.components

// Only what is out of the ordinary. Empty most of the time, and then the
// island disappears.
Island {
    id: root
    required property var bar
    padding: 4
    spacing: 0

    component Flag: BarItem {
        id: flag
        property string icon
        property color tint: Theme.fg
        property string label: ""
        hpad: 6
        spacing: 4
        Glyph { anchors.verticalCenter: parent.verticalCenter; text: flag.icon; color: flag.tint }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: flag.label
            color: flag.tint
            size: Theme.fontSmall
            bold: true
        }
    }

    // Privacy: an app records the mic / the camera / the screen.
    Flag {
        id: priv
        visible: Audio.micInUse || Audio.cameraInUse || Audio.screenShared
        icon: Audio.screenShared ? "󰹑" : (Audio.cameraInUse ? "󰄀" : "󰍬")
        tint: Theme.love
        label: [Audio.micInUse && (Audio.screenShared || Audio.cameraInUse) ? "󰍬" : "",
                Audio.cameraInUse && Audio.screenShared ? "󰄀" : ""].join("")
        onLeftClicked: root.bar.pop("control", priv)
    }

    // Homelab: problems, or the agent waits for an approval.
    Flag {
        id: lab
        visible: Homelab.reachable && (!Homelab.healthy || Homelab.pending.length > 0)
        icon: Homelab.problems.length > 0 ? "󰒍" : "󰀨"
        tint: Homelab.problems.length > 0 ? Theme.love : Theme.gold
        label: String(Homelab.problems.length + Homelab.pending.length)
        onLeftClicked: root.bar.pop("homelab", lab)
    }

    // Vault unlocked: that is the state worth seeing.
    Flag {
        visible: Scripts.vault.loaded && Scripts.vault.state !== "locked"
        icon: "󰌿"
        onLeftClicked: Quickshell.execDetached(["dolphin", Host.home + "/Vault"])
        onRightClicked: Scripts.run("vault", ["lock"])
    }

    Flag {
        visible: Scripts.touchpad.enabled && Scripts.touchpad.state === "off"
        icon: "󰍾"
        tint: Theme.fgMuted
        onLeftClicked: Scripts.run("touchpad", ["toggle"])
    }

    // Laptop: anything louder than Quiet.
    Flag {
        visible: Scripts.powerprofile.enabled && Scripts.powerprofile.loaded && Scripts.powerprofile.state !== "quiet"
        icon: Scripts.powerprofile.state === "performance" ? "󰓅" : "󰾅"
        onLeftClicked: Scripts.run("powerprofile", ["quiet"])
    }

    // Laptop: the local Open WebUI is running.
    Flag {
        id: ai
        visible: Scripts.ai.enabled && Scripts.ai.loaded && !Scripts.ai.has("off")
        icon: "󰚩"
        tint: Scripts.ai.has("busy") ? Theme.fg : Theme.fgMuted
        onLeftClicked: Scripts.run("ai", ["open"])
        onMiddleClicked: Scripts.run("ai", ["images"])
        onRightClicked: Scripts.run("ai", ["toggle"])
        SequentialAnimation on opacity {
            running: Scripts.ai.has("starting")
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    Flag {
        id: mem
        visible: Sys.memHigh
        icon: "󰍛"
        tint: Theme.gold
        label: Math.round(Sys.memFraction * 100) + "%"
        onLeftClicked: root.bar.pop("system", mem)
    }

    Flag {
        visible: Shell.caffeine
        icon: "󰅶"
        onLeftClicked: Shell.setCaffeine(false)
    }

    Flag {
        id: dnd
        visible: Notifs.dnd
        icon: "󰂛"
        tint: Theme.fgMuted
        onLeftClicked: root.bar.pop("notifs", dnd)
        onRightClicked: Notifs.setDnd(false)
    }

    Flag {
        id: bell
        visible: Notifs.unread > 0 && !Notifs.dnd
        icon: "󰂚"
        label: String(Notifs.unread)
        onLeftClicked: root.bar.pop("notifs", bell)
        onRightClicked: Notifs.markRead()
    }

    Flag {
        id: net
        visible: !Net.online || Net.limited
        icon: Net.online ? "󰤫" : "󰤮"
        tint: Net.online ? Theme.gold : Theme.love
        onLeftClicked: root.bar.pop("control", net)
    }
}
