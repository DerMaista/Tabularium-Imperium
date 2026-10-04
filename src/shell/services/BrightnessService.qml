pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // wl-gammarelay-rs can join the bus after the shell has connected, so
    // track availability from the backend's events, not the startup caps.
    property bool available: false

    property real value: 1

    readonly property int percent: Math.round(root.value * 100)

    readonly property real step: 0.05

    function applyState(data) {
        if (!data)
            return;
        if (data.available !== undefined)
            root.available = data.available;
        if (data.value !== undefined)
            root.value = data.value;
    }

    function set(value) {
        if (!root.available)
            return;

        root.value = Math.max(0, Math.min(1, value));

        BackendService.sendRequest("brightness.set", {
            "value": root.value
        }, response => {
            if (response.error) {
                console.warn("brightness: " + response.error);
                return;
            }
            root.applyState(response.result);
        });
    }

    function adjust(delta) {
        root.set(root.value + delta);
    }

    function refresh() {
        BackendService.sendRequest("brightness.get", null, response => {
            if (response.error)
                return;
            root.applyState(response.result);
        });
    }

    Connections {
        target: BackendService

        function onBrightnessEvent(data) {
            root.applyState(data);
        }

        function onLinkUp() {
            root.refresh();
        }

        function onLinkDown() {
            root.available = false;
        }
    }
}
