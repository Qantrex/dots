pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight through brightnessctl (no root needed; works through logind).
// sysfs does not send change events, so the value is re-read after every
// change the shell makes and whenever `qs ipc call osd brightness` is called.
Singleton {
    id: root

    property bool available: false
    property real value: 0      // 0..1

    signal userChange()
    property bool announce: false

    // announce: show the OSD once the new value is read (brightness keys).
    function refresh(announce) {
        root.announce = root.announce || !!announce;
        reader.running = true;
    }
    function set(v) {
        v = Math.max(0.01, Math.min(1, v));
        value = v;
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(v * 100) + "%"]);
    }
    function step(delta) {
        Quickshell.execDetached(["sh", "-c", "brightnessctl -q -e4 -n2 set " + Math.abs(Math.round(delta * 100))
                                 + "%" + (delta > 0 ? "+" : "-")]);
        refreshLater.restart();
    }

    Timer {
        id: refreshLater
        interval: 120
        onTriggered: root.refresh(false)
    }

    Process {
        id: reader
        command: ["brightnessctl", "-m", "-c", "backlight"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // amdgpu_bl1,backlight,180000,45%,400000
                const f = text.trim().split(",");
                if (f.length >= 5) {
                    root.available = true;
                    root.value = Number(f[2]) / Number(f[4]);
                }
                if (root.announce) {
                    root.announce = false;
                    root.userChange();
                }
            }
        }
    }
}
