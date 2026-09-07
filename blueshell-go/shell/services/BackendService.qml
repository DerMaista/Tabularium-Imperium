pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("BLUESHELL_SOCKET")

    property int apiVersion: 0
    property var capabilities: []
    readonly property int expectedApiVersion: 1
    property bool connected: false

    readonly property var topics: ["metrics", "workspaces", "network", "clock", "theme"]

    signal metricsEvent(var data)
    signal workspacesEvent(var data)
    signal networkEvent(var data)
    signal clockEvent(var data)
    signal themeEvent(var data)

    signal linkUp
    signal linkDown

    function has(capability) {
        return root.capabilities.indexOf(capability) !== -1;
    }

    property var pendingRequests: ({})
    property int requestIdCounter: 0

    function sendRequest(method, params, callback) {
        if (!root.connected) {
            if (callback)
                callback({
                    "error": "not connected to blueshell backend"
                });
            return;
        }

        root.requestIdCounter++;
        const id = root.requestIdCounter;
        const request = {
            "id": id,
            "method": method
        };
        if (params)
            request.params = params;
        if (callback)
            root.pendingRequests[id] = callback;

        requestSocket.send(request);
    }

    function handleResponse(obj) {
        const callback = root.pendingRequests[obj.id];
        if (!callback)
            return;
        delete root.pendingRequests[obj.id];
        callback(obj);
    }

    function failPendingRequests() {
        const pending = root.pendingRequests;
        root.pendingRequests = {};
        for (const id in pending)
            pending[id]({
                "error": "backend disconnected"
            });
    }

    function handleBanner(obj) {
        root.apiVersion = obj.apiVersion || 0;
        root.capabilities = obj.capabilities || [];
        console.info("blueshell backend: API v" + root.apiVersion + " caps=" + JSON.stringify(root.capabilities));

        if (root.apiVersion < root.expectedApiVersion)
            console.warn("backend is older than this UI expects (v" + root.apiVersion + " < v" + root.expectedApiVersion + ")");
    }

    function routeEvent(obj) {
        switch (obj.event) {
        case "metrics":
            root.metricsEvent(obj.data);
            break;
        case "workspaces":
            root.workspacesEvent(obj.data);
            break;
        case "network":
            root.networkEvent(obj.data);
            break;
        case "clock":
            root.clockEvent(obj.data);
            break;
        case "theme":
            root.themeEvent(obj.data);
            break;
        }
    }

    function isBanner(obj) {
        return obj.apiVersion !== undefined && obj.event === undefined && obj.id === undefined;
    }

    Component.onCompleted: {
        if (root.socketPath.length === 0) {
            console.warn("BLUESHELL_SOCKET is unset — the UI was started without its backend. " + "Run `blueshell run` rather than `qs -p` directly.");
            return;
        }
        requestSocket.connected = true;
    }

    JsonSocket {
        id: requestSocket

        path: root.socketPath
        connected: false

        onConnectedChanged: {
            root.connected = connected;
            if (connected) {
                subscribeSocket.connected = true;
                root.linkUp();
                return;
            }

            root.apiVersion = 0;
            root.capabilities = [];
            subscribeSocket.connected = false;
            root.failPendingRequests();
            root.linkDown();
        }

        onMessage: obj => {
            if (root.isBanner(obj)) {
                root.handleBanner(obj);
                return;
            }
            root.handleResponse(obj);
        }
    }

    JsonSocket {
        id: subscribeSocket

        path: root.socketPath
        connected: false

        onConnectedChanged: {
            if (!connected)
                return;
            send({
                "id": 1,
                "method": "subscribe",
                "params": {
                    "topics": root.topics
                }
            });
        }

        onMessage: obj => {
            if (obj.event !== undefined)
                root.routeEvent(obj);
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.socketPath.length > 0 && !requestSocket.connected

        onTriggered: requestSocket.connected = true
    }
}
