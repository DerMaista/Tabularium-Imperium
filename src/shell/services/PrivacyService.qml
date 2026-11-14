pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

import qs.config

// Which applications are recording right now. PipeWire answers for the
// microphone, screen casts and cameras opened through it; cameras opened
// directly through V4L2 (most browsers) come from the backend, which watches
// the device nodes.
Singleton {
    id: root

    // Every link whose source is a capture device, with the node consuming it.
    readonly property var captureLinks: {
        const out = [];
        for (const group of Pipewire.linkGroups.values) {
            const source = group.source;
            const target = group.target;
            if (!source || !target || source.isStream)
                continue;
            if (root.isMicrophone(source) || root.isVideoSource(source))
                out.push(group);
        }
        return out;
    }

    // Stream properties (application name, passive flag) are only filled in
    // once the node is bound.
    PwObjectTracker {
        objects: root.captureLinks.map(group => group.target)
    }

    function has(type, flag) {
        return (type & flag) === flag;
    }

    function isMicrophone(node) {
        return root.has(node.type, PwNodeType.AudioSource) && !node.isSink;
    }

    function isVideoSource(node) {
        return root.has(node.type, PwNodeType.VideoSource);
    }

    // Cameras come from the v4l2 or libcamera monitors; anything else that
    // produces video (xdg-desktop-portal's screen cast node) is a screen.
    function isCamera(node) {
        const name = node.name || "";
        return name.startsWith("v4l2_input") || name.startsWith("libcamera_input");
    }

    function appName(node) {
        const props = node.properties || {};
        return props["application.name"] || props["application.process.binary"] || node.description || node.name || "unknown";
    }

    // Filter chains (echo cancel, noise suppression) hold the microphone
    // open permanently and mark themselves passive or virtual; they are not
    // somebody listening.
    function passive(node) {
        const props = node.properties || {};
        return props["node.passive"] === "true" || props["node.passive"] === true || props["node.virtual"] === "true" || props["node.virtual"] === true;
    }

    function ignored(name) {
        const list = Config.privacyIgnore || [];
        const lower = name.toLowerCase();
        for (const entry of list) {
            if (String(entry).toLowerCase() === lower)
                return true;
        }
        return false;
    }

    function collect(predicate) {
        const seen = {};
        const out = [];
        for (const group of root.captureLinks) {
            if (!predicate(group.source) || root.passive(group.target))
                continue;
            const name = root.appName(group.target);
            if (seen[name] || root.ignored(name))
                continue;
            seen[name] = true;
            out.push(name);
        }
        return out;
    }

    readonly property var micApps: root.collect(node => root.isMicrophone(node))

    readonly property var screencastApps: root.collect(node => root.isVideoSource(node) && !root.isCamera(node))

    property var directCameraApps: []

    readonly property var cameraApps: {
        const out = root.collect(node => root.isVideoSource(node) && root.isCamera(node));
        for (const name of root.directCameraApps) {
            if (out.indexOf(name) === -1 && !root.ignored(name))
                out.push(name);
        }
        return out;
    }

    readonly property bool micActive: root.micApps.length > 0
    readonly property bool cameraActive: root.cameraApps.length > 0
    readonly property bool screencastActive: root.screencastApps.length > 0
    readonly property bool active: root.micActive || root.cameraActive || root.screencastActive

    Connections {
        target: BackendService

        function onCameraEvent(data) {
            root.directCameraApps = data && data.apps ? data.apps : [];
        }

        function onLinkDown() {
            root.directCameraApps = [];
        }
    }
}
