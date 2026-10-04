pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    readonly property var items: SystemTray.items.values

    readonly property int count: root.items.length

    property var menuItem: null
    property string menuScreen: ""
    property real menuX: 0
    property real menuY: 0

    readonly property bool menuOpen: root.menuItem !== null

    function openMenu(item, screenName, x, y) {
        if (!item || !item.hasMenu)
            return;

        root.menuItem = item;
        root.menuScreen = screenName;
        root.menuX = x;
        root.menuY = y;
    }

    function closeMenu() {
        root.menuItem = null;
    }

    function toggleMenu(item, screenName, x, y) {
        if (root.menuItem === item) {
            root.closeMenu();
            return;
        }

        root.openMenu(item, screenName, x, y);
    }

    onItemsChanged: {
        if (root.menuItem && root.items.indexOf(root.menuItem) === -1)
            root.closeMenu();
    }
}
