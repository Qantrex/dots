pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The notification daemon (replaces mako). Popups show for a few seconds;
// everything stays in the history until dismissed. Do Not Disturb hides the
// popups but keeps the history; critical ones always show.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values.slice().reverse()   // newest first
    property var popups: []
    property int unread: 0
    property bool dnd: persist.dnd

    PersistentProperties {
        id: persist
        reloadableId: "notifs"
        property bool dnd: false
    }

    function setDnd(on) { persist.dnd = on; }
    function markRead() { unread = 0; }
    function dismissPopup(n) { popups = popups.filter(p => p !== n); }
    // Remove an app's notifications from the popups and the history (the battery warnings once plugged in).
    function dismissApp(app) {
        for (const n of server.trackedNotifications.values.slice()) if (n.appName === app) n.dismiss();
        popups = popups.filter(p => p.appName !== app);
    }
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        popups = [];
        unread = 0;
    }
    // expireTimeout is the sender's value in ms (quickshell 0.3.2 passes the D-Bus value through; its docs say seconds).
    function timeoutFor(n) {
        // Critical ones stay until dismissed; the battery warning goes after its own timeout (60 s, Power.qml).
        if (n.urgency === NotificationUrgency.Critical)
            return n.appName === "Battery" && n.expireTimeout > 0 ? n.expireTimeout : 0;
        if (n.expireTimeout > 0) return Math.min(n.expireTimeout, 15000);
        return n.urgency === NotificationUrgency.Low ? 3000 : 5000;
    }
    function icon(n) {
        if (n.image) return n.image;
        if (n.appIcon) return n.appIcon.startsWith("/") || n.appIcon.includes("://") ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
        return "";
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            if (n.transient && root.dnd) return;
            root.unread += 1;
            if (!root.dnd || n.urgency === NotificationUrgency.Critical) {
                root.popups = [n].concat(root.popups.filter(p => p.id !== n.id)).slice(0, 5);
                Neko.sound("notify");   // nekosec only, and only for popups (so never in DND)
            }
            n.closed.connect(() => root.dismissPopup(n));
        }
    }
}
