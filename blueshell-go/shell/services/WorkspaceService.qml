pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: BackendService.has("workspaces")

    property var monitors: ({})

    property int minActiveClients: 0

    signal monitorUpdated(string name)

    function tagsFor(name) {
        const entry = root.monitors[name];
        return entry ? entry.tags : [];
    }

    function activeTagFor(name) {
        const entry = root.monitors[name];
        return entry ? entry.activeTag : 0;
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

        function onLinkDown() {
            root.monitors = ({});
            root.minActiveClients = 0;
        }
    }
}
