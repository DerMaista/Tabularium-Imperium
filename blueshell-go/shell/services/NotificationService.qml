pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import qs.config

Singleton {
    id: root

    // The one and only notification server. It has to be a singleton rather
    // than something the popup surface owns: `shell.qml` instantiates its
    // Variants delegate once per monitor, and two NotificationServers would
    // race each other for the org.freedesktop.Notifications bus name.
    NotificationServer {
        id: server

        // Carried-over notifications survive a QML hot reload, so editing a
        // delegate under `blueshell run -c ./shell` no longer empties history.
        keepOnReload: true

        actionsSupported: true
        bodySupported: true
        imageSupported: true
        persistenceSupported: true

        // Advertised honestly: the cards render `body` as plain text, so markup
        // is shown rather than interpreted and no <img> can pull in a remote
        // resource. Inline replies have no UI, so they are not claimed either.
        actionIconsSupported: false
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        inlineReplySupported: false

        onNotification: n => {
            n.tracked = true;
            root.remember(n);
            root.enforceHistoryLimit();

            // A notification the server carried across a reload is already in
            // history and was shown as a toast by the previous generation.
            // Re-toasting the whole backlog on every QML edit is what
            // `lastGeneration` exists to prevent.
            if (n.lastGeneration)
                return;

            root.raisePopup(n);
        }
    }

    // ---- history ----

    // The tracked list is the single source of truth. An app that closes its
    // own notification (CloseNotification — a YubiKey does this once you touch
    // it) drops out of it without telling us, so deriving history from it means
    // there is no second list that can go stale. The original daemon kept a
    // parallel ListModel of copies, which is why its per-row close button
    // called `history.remove(modelData.index)` on an `index` that a ListModel
    // delegate's `modelData` does not carry — that button never worked.
    readonly property var history: {
        const values = server.trackedNotifications.values;
        const out = [];
        // Newest first. `values` is a QObjectList: array-*like*, but not a real
        // Array, so it has no .reverse() — the same trap as `colorBezier`.
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

    // Oldest-first eviction, so a chatty app cannot grow the tracked list
    // without bound. Keeping notifications tracked is what makes their images
    // and actions still work in the centre, and it is also what would make an
    // unbounded history a real leak rather than a cosmetic one.
    function enforceHistoryLimit() {
        const limit = Config.notificationsHistoryLimit;
        if (limit <= 0)
            return;

        const values = server.trackedNotifications.values;
        const excess = values.length - limit;
        if (excess <= 0)
            return;

        // Snapshot before closing anything: `values` is live and expire()
        // mutates it.
        const doomed = [];
        for (let i = 0; i < excess; i++)
            doomed.push(values[i]);
        for (const n of doomed)
            n.expire();

        root.pruneArrivals();
    }

    // ---- arrival times ----

    // A quickshell Notification carries no timestamp, so arrival is recorded
    // here. Epoch ms rather than a formatted string, so the centre gets to
    // decide how much of it to show.
    property var arrivals: ({})

    function remember(n) {
        const arrivals = root.arrivals;
        arrivals[n.id] = Date.now();
        root.arrivals = arrivals;
    }

    // Ids are not reused within a session, so without this the map would keep
    // an entry for every notification ever received.
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

    // ---- toasts ----

    // Ids with a toast still on screen. Toast visibility is deliberately not
    // the same thing as being tracked: a toast that times out leaves the
    // corner, not the history. The original got that behaviour by holding a
    // second copy of every notification; here one list does both jobs.
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

    // A burst of notifications should not paper over the screen.
    readonly property var visiblePopups: {
        const limit = Config.notificationsPopupLimit;
        if (limit <= 0 || root.popups.length <= limit)
            return root.popups;
        return root.popups.slice(0, limit);
    }

    readonly property int hiddenPopupCount: root.popups.length - root.visiblePopups.length

    // How long this notification's toast should stay up, in ms. 0 means "until
    // something closes it".
    function popupTimeout(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        // The sender's own timeout, which the original daemon ignored entirely:
        // 0 means never expire, -1 means "you decide".
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

        // An app replacing a notification in place (a progress bar, a volume
        // OSD) re-emits the signal for an id already on screen. Re-arming its
        // deadline above is the whole update; the id must not be added twice.
        if (root.popupIds.indexOf(n.id) === -1)
            root.popupIds = root.popupIds.concat([n.id]);

        root.scheduleReaper();
    }

    // id -> epoch ms at which the toast comes down. Absolute deadlines and one
    // shared timer, rather than a Timer per card: a Timer living in a delegate
    // restarts whenever the model around it changes, so in the original every
    // visible card's countdown began again each time a new notification
    // arrived — and there was one such Timer per monitor.
    property var deadlines: ({})

    // One timer for the whole shell, always armed for the nearest deadline.
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

        // Collect first: hidePopup mutates `deadlines` underneath.
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

    // Drops the toast and nothing else. Split out from hidePopup so callers
    // that are about to close the notification anyway do not touch it twice.
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

        // A transient notification is one the sender asked us not to keep, so
        // for these — and only these — the toast coming down is the end of it.
        if (n && n.transient)
            n.expire();
    }

    function dismiss(n) {
        root.forgetPopup(n.id);
        n.dismiss();
        root.pruneArrivals();
    }

    function clearAll() {
        // Snapshot first: the tracked list shrinks under the loop.
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
        // Read what we need before invoking: a non-resident notification can be
        // gone by the time invoke() returns.
        const id = n.id;
        const resident = n.resident;

        action.invoke();
        root.forgetPopup(id);

        if (resident)
            return;

        // The spec closes a notification once one of its actions is taken.
        // Looking it up again rather than reusing `n` covers the case where
        // invoke() has already closed it.
        const target = root.find(id);
        if (target)
            target.dismiss();
    }

    // ---- the centre ----

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
