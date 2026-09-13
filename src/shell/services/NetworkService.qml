pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: BackendService.has("network")

    property bool connected: false
    property string name: "OFFLINE"
    property string type: "none"
    property int strength: 0

    readonly property string label: root.connected ? root.name.toUpperCase() : "OFFLINE"

    function applyState(data) {
        if (!data)
            return;
        root.connected = data.connected === true;
        root.name = data.name || "OFFLINE";
        root.type = data.type || "none";
        root.strength = data.strength || 0;
    }

    Connections {
        target: BackendService

        function onNetworkEvent(data) {
            root.applyState(data);
        }

        function onLinkDown() {
            root.connected = false;
            root.name = "OFFLINE";
            root.strength = 0;
        }
    }
}
