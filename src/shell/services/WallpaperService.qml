pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Mirrors the backend's wallpaper state: blueprint grid with sigil, or an image.
Singleton {
    id: root

    readonly property bool available: BackendService.has("wallpaper")

    property string mode: "sigil"
    property string image: ""
    // "image" only when image mode has a readable image; the backend decides.
    property string showing: "sigil"

    // The current theme and its set of wallpapers (wallpaper.list).
    property string theme: ""
    property var wallpapers: []
    property string dir: ""
    property bool loading: false

    // False until the backend has reported what to show (or it gave up waiting),
    // so the wallpaper doesn't flash the sigil default at startup.
    property bool known: false

    readonly property bool showImage: root.showing === "image" && root.image.length > 0
    readonly property url source: root.image.length > 0 ? "file://" + root.image : ""

    // Emitted on every backend update so a view whose image failed to load can retry.
    signal updated

    function update(data) {
        if (!data)
            return;
        if (data.mode !== undefined)
            root.mode = data.mode;
        if (data.image !== undefined)
            root.image = data.image;
        if (data.showing !== undefined)
            root.showing = data.showing;
        if (data.theme !== undefined && data.theme !== root.theme) {
            root.theme = data.theme;
            root.refresh();
        } else if (data.listChanged) {
            // New picker thumbnails are ready.
            root.refresh();
        }
        root.known = true;
        root.updated();
    }

    // No backend (or no wallpaper support): fall back to the sigil defaults.
    Timer {
        interval: 1500
        running: !root.known
        onTriggered: root.known = true
    }

    function refresh() {
        if (root.loading)
            return;
        root.loading = true;

        BackendService.sendRequest("wallpaper.list", null, response => {
            root.loading = false;
            if (response.error || !response.result)
                return;
            root.wallpapers = response.result.wallpapers || [];
            root.dir = response.result.dir || "";
            root.update(response.result);
        });
    }

    // Shows an image, or the sigil for an empty path; remembered per theme.
    function pick(path) {
        BackendService.sendRequest("wallpaper.pick", {
            "path": path
        }, response => {
            if (!response.error)
                root.update(response.result);
        });
    }

    function setMode(mode) {
        BackendService.sendRequest("wallpaper.mode", {
            "mode": mode
        }, response => {
            if (!response.error)
                root.update(response.result);
        });
    }

    function toggle() {
        root.setMode("toggle");
    }

    Connections {
        target: BackendService

        function onWallpaperEvent(data) {
            root.update(data);
        }

        function onLinkUp() {
            BackendService.sendRequest("wallpaper.current", null, response => {
                if (!response.error)
                    root.update(response.result);
                else
                    root.known = true;
            });
        }
    }
}
