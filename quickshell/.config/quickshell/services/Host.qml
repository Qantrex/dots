pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which machine this is. bauarch = laptop (battery, touchpad, asusctl, local
// AI web UI); bauarch-pc = desktop (the AI node). Same split as hypr/lua/host.lua.
Singleton {
    id: root

    readonly property string name: file.text().trim()
    readonly property bool isPc: name === "bauarch-pc"
    readonly property bool isLaptop: !isPc
    readonly property string home: Quickshell.env("HOME")

    FileView {
        id: file
        path: "/etc/hostname"
        blockLoading: true
    }
}
