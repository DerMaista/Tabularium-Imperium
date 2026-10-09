pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: BackendService.has("workspaces")

    property var monitors: ({})

    property int minActiveClients: 0

    // Compositor-wide: mango has one keymode, not one per output.
    property string keymode: "default"

    signal monitorUpdated(string name)

    function tagsFor(name) {
        const entry = root.monitors[name];
        return entry ? entry.tags : [];
    }

    function activeTagFor(name) {
        const entry = root.monitors[name];
        return entry ? entry.activeTag : 0;
    }

    function layoutFor(name) {
        const entry = root.monitors[name];
        return entry && entry.layout ? entry.layout : "";
    }

    function dispatch(command) {
        BackendService.sendRequest("workspaces.dispatch", {
            "command": command
        });
    }

    function view(tagIndex) {
        root.dispatch("view," + tagIndex + ",0");
    }

    function applyMonitor(data) {
        if (!data || !data.monitor)
            return;

        const map = root.monitors;
        map[data.monitor] = data;
        root.monitors = map;

        let smallest = -1;
        for (const name in map) {
            const clients = map[name].activeClients;
            if (smallest < 0 || clients < smallest)
                smallest = clients;
        }
        root.minActiveClients = smallest < 0 ? 0 : smallest;

        root.monitorUpdated(data.monitor);
    }

    Connections {
        target: BackendService

        function onWorkspacesEvent(data) {
            root.applyMonitor(data);
        }

        function onKeymodeEvent(data) {
            if (data && data.keymode)
                root.keymode = data.keymode;
        }

        function onLinkDown() {
            root.monitors = ({});
            root.minActiveClients = 0;
            root.keymode = "default";
        }
    }
}
