pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: BackendService.has("power")

    readonly property var actions: [
        {
            "id": "lock",
            "icon": ""
        },
        {
            "id": "suspend",
            "icon": ""
        },
        {
            "id": "hibernate",
            "icon": "󰒲"
        },
        {
            "id": "logout",
            "icon": ""
        },
        {
            "id": "reboot",
            "icon": ""
        },
        {
            "id": "poweroff",
            "icon": ""
        }
    ]

    property var status: ({})

    property bool loading: false
    property bool busy: false
    property string error: ""

    property bool panelOpen: false

    property int selectedIndex: -1

    function actionAvailable(id) {
        const entry = root.status[id];
        return entry ? entry.available : false;
    }

    function actionReason(id) {
        const entry = root.status[id];
        return entry ? entry.reason : "";
    }

    function openPanel() {
        if (!root.available)
            return;
        root.selectedIndex = -1;
        root.error = "";
        root.refresh();
        root.panelOpen = true;
    }

    function closePanel() {
        root.panelOpen = false;
    }

    function togglePanel() {
        if (root.panelOpen)
            root.closePanel();
        else
            root.openPanel();
    }

    function moveSelection(delta) {
        const count = root.actions.length;
        if (count === 0)
            return;

        let index = root.selectedIndex < 0 ? (delta > 0 ? -1 : 0) : root.selectedIndex;
        for (let step = 0; step < count; step++) {
            index = (index + delta + count) % count;
            if (root.actionAvailable(root.actions[index].id)) {
                root.selectedIndex = index;
                return;
            }
        }
    }

    function activateSelected() {
        const action = root.actions[root.selectedIndex];
        if (action)
            root.invoke(action.id);
    }

    function invoke(id) {
        if (root.busy || !root.actionAvailable(id))
            return;
        root.busy = true;
        root.error = "";

        BackendService.sendRequest("power.invoke", {
            "action": id
        }, response => {
            root.busy = false;
            if (response.error) {
                root.error = response.error;
                return;
            }
            root.closePanel();
        });
    }

    function refresh() {
        if (root.loading)
            return;
        root.loading = true;

        BackendService.sendRequest("power.list", null, response => {
            root.loading = false;
            if (response.error) {
                root.error = response.error;
                root.status = {};
                return;
            }
            root.error = "";

            const status = {};
            for (const entry of response.result.actions || [])
                status[entry.id] = {
                    "available": entry.available,
                    "reason": entry.reason
                };
            root.status = status;

            if (root.selectedIndex >= 0 && !root.actionAvailable(root.actions[root.selectedIndex].id))
                root.selectedIndex = -1;
        });
    }

    Connections {
        target: BackendService

        function onLinkDown() {
            root.status = {};
            root.panelOpen = false;
            root.busy = false;
        }
    }
}
