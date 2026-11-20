// Notification server (replaces mako). Keeps every notification as history until it is
// dismissed, shows new ones as popups (Popups.qml) unless Do Not Disturb is on, and
// remembers when each arrived. `import qs`, then Notifs.list / .popups / .dnd.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values.slice().reverse()   // newest first
    property var popups: []           // notifications currently shown as popups
    property bool dnd: false
    property var times: ({})          // id -> arrival time (ms)
    property bool unread: false       // something arrived since the clock panel was last opened
    // Popup deadlines live here, not in the cards: the cards are rebuilt whenever the popup
    // list changes, which would restart their timers
    property var until: ({})          // id -> time (ms) the popup hides; critical: never
    property int hovering: -1         // id of the popup under the mouse (its deadline waits)

    function age(n) {
        const t = times[n.id];
        if (!t)
            return "";
        const s = Math.floor((Date.now() - t) / 1000);
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d";
    }

    // Image or icon for a notification: its image, else its app icon, else a generic one
    function icon(n) {
        if (n.image)
            return n.image;
        const i = n.appIcon || n.desktopEntry;
        if (i.startsWith("/") || i.startsWith("file:") || i.startsWith("image:"))
            return i;
        return Quickshell.iconPath(i || DesktopEntries.heuristicLookup(n.appName)?.icon || "", "dialog-information");
    }

    // Hide the popup but keep the notification in history (transient ones are dropped)
    function unpop(n) {
        popups = popups.filter(p => p !== n);
        if (n.transient)
            n.dismiss();
    }

    // Click on a notification: run its default action if it has one, then dismiss it
    function activate(n) {
        const a = n.actions.find(x => x.identifier === "default");
        if (a)
            a.invoke();
        n.dismiss();
    }

    function clearAll() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    Timer {
        running: root.popups.length > 0
        repeat: true
        interval: 250
        onTriggered: {
            const now = Date.now();
            for (const n of root.popups) {
                if (n.id === root.hovering)
                    root.until[n.id] = Math.max(root.until[n.id], now + 1500);
                else if (now >= root.until[n.id])
                    root.unpop(n);
            }
        }
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            root.times[n.id] = Date.now();
            root.unread = true;
            if (!root.dnd || n.urgency === NotificationUrgency.Critical) {
                root.until[n.id] = n.urgency === NotificationUrgency.Critical ? Infinity
                    : Date.now() + (n.expireTimeout > 0 ? n.expireTimeout : 5000);
                root.popups = [n].concat(root.popups).slice(0, 5);
            }
            n.closed.connect(() => root.popups = root.popups.filter(p => p !== n));
        }
    }
}
