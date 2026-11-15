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
        tip: [Audio.screenShared ? "Screen is being shared" : "",
              Audio.cameraInUse ? "Camera in use" : "",
              Audio.micInUse ? "Microphone in use: " + [...new Set(Audio.micUsers)].join(", ") : ""].filter(x => x).join("\n")
        onLeftClicked: root.bar.pop("control", priv)
    }

    // Homelab: problems, or the agent waits for an approval.
    Flag {
        id: lab
        visible: Homelab.reachable && (!Homelab.healthy || Homelab.pending.length > 0)
        icon: Homelab.problems.length > 0 ? "󰒍" : "󰀨"
        tint: Homelab.problems.length > 0 ? Theme.love : Theme.gold
        label: String(Homelab.problems.length + Homelab.pending.length)
        tip: Homelab.problems.map(x => x.text || String(x)).concat(
                 Homelab.pending.length ? [Homelab.pending.length + " approval(s) waiting"] : []).join("\n")
        onLeftClicked: root.bar.pop("homelab", lab)
    }

    // Vault unlocked: that is the state worth seeing.
    Flag {
        visible: Scripts.vault.loaded && Scripts.vault.state !== "locked"
        icon: "󰌿"
        tip: "Vault is open\nClick: open ~/Vault · right-click: lock"
        onLeftClicked: Quickshell.execDetached(["xdg-open", Host.home + "/Vault"])
        onRightClicked: Scripts.run("vault", ["lock"])
    }

    Flag {
        visible: Scripts.touchpad.enabled && Scripts.touchpad.state === "off"
        icon: "󰍾"
        tint: Theme.fgMuted
        tip: "Touchpad is off\nClick or Fn+F6: turn it on"
        onLeftClicked: Scripts.run("touchpad", ["toggle"])
    }

    // Laptop: anything louder than Quiet.
    Flag {
        visible: Scripts.powerprofile.enabled && Scripts.powerprofile.loaded && Scripts.powerprofile.state !== "quiet"
        icon: Scripts.powerprofile.state === "performance" ? "󰓅" : "󰾅"
        tip: Scripts.powerprofile.tooltip.split("\n\n")[0] + "\nClick: back to Quiet"
        onLeftClicked: Scripts.run("powerprofile", ["quiet"])
    }

    // Laptop: the local Open WebUI is running.
    Flag {
        id: ai
        visible: Scripts.ai.enabled && Scripts.ai.loaded && !Scripts.ai.has("off")
        icon: "󰚩"
        tint: Scripts.ai.has("busy") ? Theme.fg : Theme.fgMuted
        tip: Scripts.ai.tooltip.split("\n\n")[0] + "\nClick: open · middle: Image Studio · right: stop"
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

    // Claude plan usage: only from 70 % of the 5-hour or the weekly window.
    Flag {
        visible: ClaudeUsage.high
        icon: "󰊚"
        tint: ClaudeUsage.peak >= 90 ? Theme.love : Theme.gold
        label: Math.round(ClaudeUsage.peak) + "%"
        tip: "Claude usage\n" + ClaudeUsage.tooltip
    }

    Flag {
        id: mem
        visible: Sys.memHigh
        icon: "󰍛"
        tint: Theme.gold
        label: Math.round(Sys.memFraction * 100) + "%"
        tip: "Memory: " + Sys.memUsed.toFixed(1) + " of " + Sys.memTotal.toFixed(1) + " GB used"
        onLeftClicked: root.bar.pop("system", mem)
    }

    Flag {
        visible: Shell.caffeine
        icon: "󰅶"
        tip: "Caffeine: the screen stays awake\nClick: turn off"
        onLeftClicked: Shell.setCaffeine(false)
    }

    Flag {
        id: dnd
        visible: Notifs.dnd
        icon: "󰂛"
        tint: Theme.fgMuted
        tip: "Do not disturb" + (Notifs.unread ? " · " + Notifs.unread + " unread" : "") + "\nClick: notifications · right-click: turn off"
        onLeftClicked: root.bar.pop("notifs", dnd)
        onRightClicked: Notifs.setDnd(false)
    }

    Flag {
        id: bell
        visible: Notifs.unread > 0 && !Notifs.dnd
        icon: "󰂚"
        label: String(Notifs.unread)
        tip: Notifs.unread + " unread\nClick: show · right-click: mark read"
        onLeftClicked: root.bar.pop("notifs", bell)
        onRightClicked: Notifs.markRead()
    }

    Flag {
        id: net
        visible: !Net.online || Net.limited
        icon: Net.online ? "󰤫" : "󰤮"
        tint: Net.online ? Theme.gold : Theme.love
        tip: Net.online ? "Connected, but no full internet access (portal or limited)" : "No network"
        onLeftClicked: root.bar.pop("control", net)
    }
}
