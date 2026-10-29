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

    // Shows the new profile right away instead of waiting for the daemon to apply
    // it; the profile event that follows confirms it, an error rolls it back.
    function set(profile) {
        if (!root.available || profile === root.active)
            return;

        const previous = root.active;
        root.active = profile;

        BackendService.sendRequest("profile.set", {
            "profile": profile
        }, response => {
            if (!response.error)
                return;
            console.warn("profile: " + response.error);
            if (root.active === profile)
                root.active = previous;
        });
    }

    function cycle() {
        if (root.profiles.length === 0) {
            root.send("profile.cycle", null);
            return;
        }
        const next = (root.profiles.indexOf(root.active) + 1) % root.profiles.length;
        root.set(root.profiles[next]);
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
