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
import qs.agentic

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
            // nekosec: the glitch between wallpapers (the first screen switches hyprpaper)
            LazyLoader {
                active: Neko.enabled
                Glitch { modelData: perScreen.modelData; primary: perScreen.modelData === Quickshell.screens[0] }
            }
            // nekosec: the seeing stone on the wallpaper, clickable
            LazyLoader {
                active: Neko.enabled
                Stone { modelData: perScreen.modelData }
            }
        }
    }

    Popups {}
    Osd {}
    Launcher {}
    LazyLoader { active: Neko.enabled; StonePanel {} }
    // The agent panel (theme root-agentic). Inline, not `source:`: a panel loaded by path made
    // Quickshell crash when it quit just after a reload.
    LazyLoader { active: Agentic.enabled; Panel {} }
}
