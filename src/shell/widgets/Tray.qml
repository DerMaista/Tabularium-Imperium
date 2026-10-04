pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray

import qs.config
import qs.services
import qs.tray

Chip {
    id: root

    readonly property bool populated: TrayService.count > 0

    readonly property real iconSize: Config.fontsize * 1.2

    visible: root.populated
    implicitWidth: root.populated ? root.contentWidth : 0
    implicitHeight: root.populated ? root.contentHeight : 0

    Row {
        spacing: root.uniformMargin / 2

        Repeater {
            model: TrayService.items

            delegate: Rectangle {
                id: entry

                required property SystemTrayItem modelData

                readonly property bool attention: entry.modelData.status === Status.NeedsAttention

                readonly property bool menuOpen: TrayService.menuItem === entry.modelData

                anchors.verticalCenter: parent.verticalCenter

                width: root.iconSize + root.strokeWidth * 2
                height: root.iconSize + root.strokeWidth * 2

                color: entry.menuOpen || entry.attention ? Colors.accent : "transparent"

                TrayIcon {
                    anchors.centerIn: parent

                    size: root.iconSize
                    source: entry.modelData.icon
                    tint: entry.menuOpen || entry.attention ? Colors.background : Colors.primary
                }

                function anchorMenu() {
                    const point = entry.mapToItem(null, entry.width / 2, entry.height);
                    TrayService.toggleMenu(entry.modelData, root.screen.name, point.x, point.y);
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            entry.anchorMenu();
                            return;
                        }

                        if (mouse.button === Qt.MiddleButton) {
                            entry.modelData.secondaryActivate();
                            return;
                        }

                        if (entry.modelData.onlyMenu) {
                            entry.anchorMenu();
                            return;
                        }

                        entry.modelData.activate();
                    }

                    onWheel: wheel => {
                        if (wheel.angleDelta.y !== 0)
                            entry.modelData.scroll(wheel.angleDelta.y, false);
                        if (wheel.angleDelta.x !== 0)
                            entry.modelData.scroll(wheel.angleDelta.x, true);
                    }
                }
            }
        }
    }
}
