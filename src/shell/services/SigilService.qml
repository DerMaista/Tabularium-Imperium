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

    function moveSelection(delta) {
        const count = root.sigils.length;
        if (count === 0)
            return;
        root.selectedIndex = (root.selectedIndex + delta + count) % count;
    }

    function activateSelected() {
        const sigil = root.sigils[root.selectedIndex];
        if (sigil)
            root.apply(sigil.name);
    }

    function selectCurrent() {
        const index = root.sigils.findIndex(sigil => sigil.name === root.current);
        root.selectedIndex = Math.max(0, index);
    }

    function openPicker() {
        if (!root.available)
            return;
        root.refresh();
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
