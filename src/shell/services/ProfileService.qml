pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: BackendService.has("profile")

    property string active: ""

    property var profiles: []

    function applyState(data) {
        if (!data)
            return;
        if (data.active !== undefined)
            root.active = data.active;
        if (data.profiles !== undefined)
            root.profiles = data.profiles;
    }

    function send(method, params) {
        if (!root.available)
            return;

        BackendService.sendRequest(method, params, response => {
            if (response.error)
                console.warn("profile: " + response.error);
        });
    }

    function set(profile) {
        root.send("profile.set", {
            "profile": profile
        });
    }

    function cycle() {
        root.send("profile.cycle", null);
    }

    function step(direction) {
        const index = root.profiles.indexOf(root.active) + direction;
        if (index >= 0 && index < root.profiles.length)
            root.set(root.profiles[index]);
    }

    function refresh() {
        if (!root.available)
            return;

        BackendService.sendRequest("profile.status", null, response => {
            if (response.error)
                return;
            root.applyState(response.result);
        });
    }

    Connections {
        target: BackendService

        function onProfileEvent(data) {
            root.applyState(data);
        }

        function onLinkUp() {
            root.refresh();
        }
    }
}
