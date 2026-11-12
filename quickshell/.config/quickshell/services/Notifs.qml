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
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        popups = [];
        unread = 0;
    }
    function timeoutFor(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0;   // stays until dismissed
        if (n.expireTimeout > 0) return Math.min(n.expireTimeout * 1000, 15000);
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
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n].concat(root.popups.filter(p => p.id !== n.id)).slice(0, 5);
            n.closed.connect(() => root.dismissPopup(n));
        }
    }
}
