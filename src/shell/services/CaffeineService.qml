pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: BackendService.has("caffeine")

    property bool active: false

    property bool inhibited: false

    readonly property bool partial: root.active && !root.inhibited

    function applyState(data) {
        if (!data)
            return;
        if (data.active !== undefined)
            root.active = data.active;
        if (data.inhibited !== undefined)
            root.inhibited = data.inhibited;
    }

    function set(active) {
        if (!root.available)
            return;

        BackendService.sendRequest("caffeine.set", {
            "active": active
        }, response => {
            if (response.error) {
                console.warn("caffeine: " + response.error);
                return;
            }
            root.applyState(response.result);
        });
    }

    function toggle() {
        root.set(!root.active);
    }

    function refresh() {
        if (!root.available)
            return;

        BackendService.sendRequest("caffeine.status", null, response => {
            if (response.error)
                return;
            root.applyState(response.result);
        });
    }

    Connections {
        target: BackendService

        function onCaffeineEvent(data) {
            root.applyState(data);
        }

        function onLinkUp() {
            root.refresh();
        }
    }
}
