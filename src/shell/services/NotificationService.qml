pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import qs.config

Singleton {
    id: root

    NotificationServer {
        id: server

        keepOnReload: true

        actionsSupported: true
        bodySupported: true
        imageSupported: true
        persistenceSupported: true

        actionIconsSupported: false
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        inlineReplySupported: false

        onNotification: n => {
            n.tracked = true;
            root.remember(n);
            root.enforceHistoryLimit();

            if (n.lastGeneration)
                return;

            root.raisePopup(n);
        }
    }

    readonly property var history: {
        const values = server.trackedNotifications.values;
        const out = [];
        for (let i = values.length - 1; i >= 0; i--)
            out.push(values[i]);
        return out;
    }

    readonly property int count: root.history.length

    readonly property bool hasCritical: {
        for (const n of root.history) {
            if (n.urgency === NotificationUrgency.Critical)
                return true;
        }
        return false;
    }

    function enforceHistoryLimit() {
        const limit = Config.notificationsHistoryLimit;
        if (limit <= 0)
            return;

        const values = server.trackedNotifications.values;
        const excess = values.length - limit;
        if (excess <= 0)
            return;

        const doomed = [];
        for (let i = 0; i < excess; i++)
            doomed.push(values[i]);
        for (const n of doomed)
            n.expire();

        root.pruneArrivals();
    }

    property var arrivals: ({})

    function remember(n) {
        const arrivals = root.arrivals;
        arrivals[n.id] = Date.now();
        root.arrivals = arrivals;
    }

    function pruneArrivals() {
        const live = {};
        for (const n of root.history)
            live[n.id] = true;

        const arrivals = root.arrivals;
        let dropped = false;
        for (const id in arrivals) {
            if (!live[id]) {
                delete arrivals[id];
                dropped = true;
            }
        }
        if (dropped)
            root.arrivals = arrivals;
    }

    function timeOf(id) {
        const at = root.arrivals[id];
        if (at === undefined)
            return "";

        const when = new Date(at);
        const now = new Date();
        const sameDay = when.getFullYear() === now.getFullYear() && when.getMonth() === now.getMonth() && when.getDate() === now.getDate();
        return Qt.formatDateTime(when, sameDay ? "HH:mm" : "ddd HH:mm");
    }

    property var popupIds: []

    readonly property var popups: {
        const ids = root.popupIds;
        if (ids.length === 0)
            return [];

        const out = [];
        for (const n of root.history) {
            if (ids.indexOf(n.id) !== -1)
                out.push(n);
        }
        return out;
    }

    readonly property var visiblePopups: {
        const limit = Config.notificationsPopupLimit;
        if (limit <= 0 || root.popups.length <= limit)
            return root.popups;
        return root.popups.slice(0, limit);
    }

    readonly property int hiddenPopupCount: root.popups.length - root.visiblePopups.length

    function popupTimeout(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        if (n.expireTimeout === 0)
            return 0;
        if (n.expireTimeout > 0)
            return Math.max(1000, Math.round(n.expireTimeout));
        return Config.notificationsTimeout;
    }

    function raisePopup(n) {
        const timeout = root.popupTimeout(n);
        if (timeout > 0) {
            const deadlines = root.deadlines;
            deadlines[n.id] = Date.now() + timeout;
            root.deadlines = deadlines;
        }

        if (root.popupIds.indexOf(n.id) === -1)
            root.popupIds = root.popupIds.concat([n.id]);

        root.scheduleReaper();
    }

    property var deadlines: ({})

    Timer {
        id: reaper

        repeat: false

        onTriggered: root.reap()
    }

    function scheduleReaper() {
        let nearest = 0;
        for (const id in root.deadlines) {
            const at = root.deadlines[id];
            if (nearest === 0 || at < nearest)
                nearest = at;
        }

        if (nearest === 0) {
            reaper.stop();
            return;
        }

        reaper.interval = Math.max(16, nearest - Date.now());
        reaper.restart();
    }

    function reap() {
        const now = Date.now();

        const due = [];
        for (const id in root.deadlines) {
            if (root.deadlines[id] <= now)
                due.push(parseInt(id));
        }

        for (const id of due)
            root.hidePopup(id);

        root.scheduleReaper();
    }

    function find(id) {
        for (const n of root.history) {
            if (n.id === id)
                return n;
        }
        return null;
    }

    function forgetPopup(id) {
        if (root.popupIds.indexOf(id) !== -1)
            root.popupIds = root.popupIds.filter(existing => existing !== id);

        if (root.deadlines[id] !== undefined) {
            const deadlines = root.deadlines;
            delete deadlines[id];
            root.deadlines = deadlines;
        }
    }

    function hidePopup(id) {
        const n = root.find(id);
        root.forgetPopup(id);

        if (n && n.transient)
            n.expire();
    }

    function dismiss(n) {
        root.forgetPopup(n.id);
        n.dismiss();
        root.pruneArrivals();
    }

    function clearAll() {
        const doomed = [];
        for (const n of root.history)
            doomed.push(n);

        root.popupIds = [];
        root.deadlines = ({});
        reaper.stop();

        for (const n of doomed)
            n.dismiss();

        root.pruneArrivals();
    }

    function invokeAction(n, action) {
        const id = n.id;
        const resident = n.resident;

        action.invoke();
        root.forgetPopup(id);

        if (resident)
            return;

        const target = root.find(id);
        if (target)
            target.dismiss();
    }

    property bool centerOpen: false

    function openCenter() {
        root.centerOpen = true;
    }

    function closeCenter() {
        root.centerOpen = false;
    }

    function toggleCenter() {
        root.centerOpen = !root.centerOpen;
    }
}
