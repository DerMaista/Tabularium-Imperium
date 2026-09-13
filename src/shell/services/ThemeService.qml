pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: BackendService.has("theme")

    property var themes: []
    property string current: ""

    property bool loading: false
    property bool applying: false
    property string error: ""

    property bool pickerOpen: false

    property bool pendingOpen: false

    property int selectedIndex: 0

    function moveSelection(delta) {
        const count = root.themes.length;
        if (count === 0)
            return;
        root.selectedIndex = (root.selectedIndex + delta + count) % count;
    }

    function activateSelected() {
        const theme = root.themes[root.selectedIndex];
        if (theme)
            root.apply(theme.name);
    }

    function selectCurrent() {
        const index = root.themes.findIndex(theme => theme.name === root.current);
        root.selectedIndex = Math.max(0, index);
    }

    function openPicker() {
        if (!root.available)
            return;
        root.refresh();
        if (root.themes.length > 0)
            root.pickerOpen = true;
        else
            root.pendingOpen = true;
    }

    function closePicker() {
        root.pendingOpen = false;
        root.pickerOpen = false;
    }

    function togglePicker() {
        if (root.pickerOpen || root.pendingOpen)
            root.closePicker();
        else
            root.openPicker();
    }

    function refresh() {
        if (root.loading)
            return;
        root.loading = true;

        BackendService.sendRequest("theme.list", null, response => {
            root.loading = false;
            if (response.error) {
                root.error = response.error;
                root.themes = [];
            } else {
                root.error = "";
                root.themes = response.result.themes || [];
                root.current = response.result.current || "";
                root.selectCurrent();
            }
            if (root.pendingOpen) {
                root.pendingOpen = false;
                root.pickerOpen = true;
            }
        });
    }

    function apply(name) {
        if (root.applying || name === "")
            return;
        root.applying = true;
        root.error = "";

        BackendService.sendRequest("theme.apply", {
            "name": name
        }, response => {
            root.applying = false;
            if (response.error) {
                root.error = response.error;
                return;
            }
            root.current = response.result.current || name;
        });
    }

    Connections {
        target: BackendService

        function onThemeEvent(data) {
            if (data && data.current !== undefined)
                root.current = data.current;
        }

        function onLinkDown() {
            root.themes = [];
            root.pendingOpen = false;
            root.pickerOpen = false;
        }
    }
}
