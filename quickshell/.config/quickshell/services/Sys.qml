pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, RAM, temperature, fan, and (desktop only) the GPU of the AI node.
// Slow poll for the bar's RAM warning; fast poll only while the System popout
// is open (`detailed`).
Singleton {
    id: root

    property bool detailed: false

    property real memUsed: 0      // GiB
    property real memTotal: 0
    readonly property real memFraction: memTotal > 0 ? memUsed / memTotal : 0
    readonly property bool memHigh: memFraction >= 0.85

    property real cpu: 0          // 0..1
    property int temp: -1         // °C
    property int fan: -1          // RPM
    property var gpu: null        // { util, memUsed, memTotal, temp } on the PC

    // Disks under 10 % free go to the main Claude chat's inbox once per mount and session (`inbox`).
    property var diskReported: ({})
    function checkDisk(mount, availKb, totalKb) {
        if (totalKb <= 0 || availKb / totalKb >= 0.10 || diskReported[mount]) return;
        diskReported[mount] = true;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/inbox", "add", "--wake", "broke", "disk",
            mount + " has only " + Math.round(availKb / 1048576) + " GB (" + Math.round(100 * availKb / totalKb) + " %) free"]);
    }

    property var lastIdle: 0
    property var lastTotal: 0

    // nvidia-smi wakes the laptop's dGPU (battery), so only on the desktop.
    readonly property bool withGpu: Host.isPc

    readonly property string script: `
        head -3 /proc/meminfo
        head -1 /proc/stat
        df -P / /home 2>/dev/null | awk 'NR > 1 {print "disk", $6, $4, $2}'
        for h in /sys/class/hwmon/hwmon*; do
            case "$(cat $h/name)" in
                k10temp|coretemp|zenpower) echo "temp $(cat $h/temp1_input 2>/dev/null)";;
                asus) echo "fan $(cat $h/fan1_input 2>/dev/null)";;
            esac
        done
        if [ "$1" = gpu ] && command -v nvidia-smi >/dev/null; then
            echo "gpu $(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits | head -1)"
        fi`

    Timer {
        interval: root.detailed ? 2000 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    Process {
        id: proc
        command: ["sh", "-c", root.script, "sys", root.detailed && root.withGpu ? "gpu" : ""]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(text) {
        let total = 0, avail = 0;
        for (const line of text.split("\n")) {
            const f = line.trim().split(/[\s,]+/);
            if (f[0] === "MemTotal:") total = Number(f[1]);
            else if (f[0] === "MemAvailable:") avail = Number(f[1]);
            else if (f[0] === "cpu") {
                const n = f.slice(1).map(Number);
                const idle = n[3] + n[4], sum = n.reduce((a, b) => a + b, 0);
                if (lastTotal > 0 && sum > lastTotal)
                    cpu = 1 - (idle - lastIdle) / (sum - lastTotal);
                lastIdle = idle; lastTotal = sum;
            } else if (f[0] === "temp" && f[1]) temp = Math.round(Number(f[1]) / 1000);
            else if (f[0] === "fan" && f[1]) fan = Number(f[1]);
            else if (f[0] === "disk" && f.length >= 4) checkDisk(f[1], Number(f[2]), Number(f[3]));
            else if (f[0] === "gpu" && f.length >= 5)
                gpu = { util: Number(f[1]) / 100, memUsed: Number(f[2]) / 1024, memTotal: Number(f[3]) / 1024, temp: Number(f[4]) };
        }
        if (total > 0) {
            memTotal = total / 1048576;
            memUsed = (total - avail) / 1048576;
        }
    }
}
