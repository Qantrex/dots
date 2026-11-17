//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import qs.bar
import qs.notifications
import qs.osd
import qs.launcher
import qs.services
import qs.neko

// Entry point. Per screen: a bar and its popouts. Once (on the focused
// screen): notification popups, the OSD and the launcher.
ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: perScreen
            required property var modelData
            Bar { id: bar; modelData: perScreen.modelData }
            Popouts { bar: bar }
            // nekosec: cat ears on the windows of this screen
            LazyLoader {
                active: Neko.enabled
                WindowEars { modelData: perScreen.modelData }
            }
        }
    }

    Popups {}
    Osd {}
    Launcher {}
}
