import QtQuick
import Quickshell
import Quickshell.Networking
import qs.services
import qs.components

// Wi-Fi networks: click to connect (known or open ones right away, secured
// new ones ask for the password inline), click the connected one to disconnect.
Column {
    id: root
    spacing: 2
    property var asking: null           // the network waiting for a password

    SectionTitle {
        width: parent.width
        text: Net.wired ? "Wired · " + (Net.wired.address || "connected") : "Networks"
        action: "Settings"
        onActionClicked: { Shell.close(); Quickshell.execDetached(["foot", "-e", "nmtui"]); }
    }

    Repeater {
        model: root.visible ? Net.wifiList.slice(0, 12) : []
        delegate: Column {
            id: entry
            required property var modelData
            readonly property bool secured: modelData.security !== WifiSecurityType.Open
            width: parent.width

            ListRow {
                width: parent.width
                icon: Net.strengthIcon(entry.modelData.signalStrength)
                title: entry.modelData.name
                subtitle: entry.modelData.stateChanging ? "Connecting…" : (entry.modelData.connected ? "Connected" : (entry.modelData.known ? "Saved" : ""))
                value: entry.secured ? "󰌾" : ""
                highlighted: entry.modelData.connected
                onClicked: {
                    const n = entry.modelData;
                    if (n.connected) n.disconnect();
                    else if (n.known || !entry.secured) n.connect();
                    else root.asking = root.asking === n ? null : n;
                }
            }

            // Password for a new secured network.
            Rectangle {
                visible: root.asking === entry.modelData
                width: parent.width
                height: visible ? 36 : 0
                radius: Theme.radiusSmall
                color: Theme.surface
                border.width: 1
                border.color: pw.activeFocus ? Theme.borderStrong : Theme.border

                TextInput {
                    id: pw
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    clip: true
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    onAccepted: { entry.modelData.connectWithPsk(text); text = ""; root.asking = null; }
                    Keys.onEscapePressed: root.asking = null
                    Label {
                        visible: !pw.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password, then Enter"
                        dim: true
                    }
                }
            }
        }
    }

    Label {
        visible: Net.wifiList.length === 0
        leftPadding: 6
        text: !Net.wifiEnabled ? "Wi-Fi is off" : "Scanning…"
        muted: true
    }
}
