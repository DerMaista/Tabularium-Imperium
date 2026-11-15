pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: BackendService.has("sigil")

    property var sigils: []
    property string current: ""
    property string path: ""
    property string userDir: ""

    property bool loading: false
    property bool applying: false
    property string error: ""

    property bool pickerOpen: false

    property int selectedIndex: 0

    readonly property url source: root.path.length > 0 ? "file://" + root.path : ""

    // Picker half shown: "image" or "sigil"; opens on the current mode, switchView flips it.
    property string view: "sigil"

    readonly property var entries: root.view === "image" ? WallpaperService.wallpapers.map(wallpaper => ({
                "kind": "image",
                "name": wallpaper.name,
                "path": wallpaper.path,
                "isDefault": !!wallpaper.default
            })) : root.sigils.map(sigil => ({
                "kind": "sigil",
                "name": sigil.name,
                "path": sigil.path,
                "isDefault": false
            }))

    function switchView() {
        root.view = root.view === "image" ? "sigil" : "image";
        root.selectCurrent();
    }

    function isCurrentEntry(entry) {
        if (!entry)
            return false;
        if (entry.kind === "image")
            return WallpaperService.showing === "image" && entry.path === WallpaperService.image;
        return WallpaperService.showing !== "image" && entry.name === root.current;
    }

    function moveSelection(delta) {
        const count = root.entries.length;
        if (count === 0)
            return;
        root.selectedIndex = (root.selectedIndex + delta + count) % count;
    }

    function activateSelected() {
        root.activate(root.selectedIndex);
    }

    // Picking an image or sigil switches to that mode and is remembered for the current theme.
    function activate(index) {
        const entry = root.entries[index];
        if (!entry)
            return;
        if (entry.kind === "image") {
            WallpaperService.pick(entry.path);
            return;
        }
        WallpaperService.pick("");
        if (entry.name !== root.current)
            root.apply(entry.name);
    }

    function selectCurrent() {
        const index = root.entries.findIndex(entry => root.isCurrentEntry(entry));
        root.selectedIndex = Math.max(0, index);
    }

    function openPicker() {
        if (!root.available)
            return;
        root.view = WallpaperService.mode === "image" ? "image" : "sigil";
        root.refresh();
        WallpaperService.refresh();
        root.selectCurrent();
        root.pickerOpen = true;
    }

    function closePicker() {
        root.pickerOpen = false;
    }

    function togglePicker() {
        if (root.pickerOpen)
            root.closePicker();
        else
            root.openPicker();
    }

    function refresh() {
        if (root.loading)
            return;
        root.loading = true;

        BackendService.sendRequest("sigil.list", null, response => {
            root.loading = false;
            if (response.error) {
                root.error = response.error;
                root.sigils = [];
                return;
            }
            root.error = "";
            root.sigils = response.result.sigils || [];
            root.current = response.result.current || "";
            root.path = response.result.path || "";
            root.userDir = response.result.userDir || "";
            root.selectCurrent();
        });
    }

    function apply(name) {
        if (root.applying || name === "")
            return;
        root.applying = true;
        root.error = "";

        BackendService.sendRequest("sigil.apply", {
            "name": name
        }, response => {
            root.applying = false;
            if (response.error) {
                root.error = response.error;
                return;
            }
            root.current = response.result.current || name;
            root.path = response.result.path || "";
        });
    }

    // Keep the selection on the current entry when the wallpaper list arrives after the sigils.
    Connections {
        target: WallpaperService

        function onWallpapersChanged() {
            if (root.pickerOpen)
                root.selectCurrent();
        }
    }

    Connections {
        target: BackendService

        function onSigilEvent(data) {
            if (!data)
                return;
            if (data.current !== undefined)
                root.current = data.current;
            if (data.path !== undefined)
                root.path = data.path;
        }

        function onLinkUp() {
            BackendService.sendRequest("sigil.current", null, response => {
                if (response.error || !response.result)
                    return;
                root.current = response.result.current || "";
                root.path = response.result.path || "";
            });
        }

        function onLinkDown() {
            root.sigils = [];
            root.pickerOpen = false;
        }
    }
}
