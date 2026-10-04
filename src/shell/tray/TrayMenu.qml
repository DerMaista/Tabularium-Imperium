pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services

PanelWindow {
    id: root

    readonly property real screenSize: root.screen ? Math.min(root.screen.width, root.screen.height) : 1000
    readonly property real uniformMargin: Math.max(root.screenSize * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    readonly property string title: {
        if (!TrayService.menuItem)
            return "";
        return TrayService.menuItem.title || TrayService.menuItem.id;
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blueshell-tray-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                TrayService.closeMenu();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onClicked: TrayService.closeMenu()
        }

        Rectangle {
            id: panel

            readonly property real maxHeight: keyScope.height * 0.6

            width: Math.max(240, Math.min(keyScope.width * 0.16, 380))
            implicitHeight: header.height + flick.height + root.uniformMargin

            // Centred under the icon it belongs to, kept inside the screen.
            x: Math.max(root.uniformMargin, Math.min(TrayService.menuX - panel.width / 2, keyScope.width - panel.width - root.uniformMargin))
            y: Math.max(root.uniformMargin, Math.min(TrayService.menuY + root.uniformMargin / 2, keyScope.height - panel.implicitHeight - root.uniformMargin))

            color: Colors.background
            border {
                width: root.strokeWidth
                color: Colors.accent
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            }

            Item {
                id: header

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: root.uniformMargin / 2
                }

                height: label.implicitHeight + root.uniformMargin / 4

                Text {
                    id: label

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    text: root.title.toUpperCase()
                    color: Colors.accent
                    opacity: 0.6
                    font.pixelSize: Config.fontsize - 3
                    font.family: Config.fontfamily
                    elide: Text.ElideRight
                }
            }

            Flickable {
                id: flick

                anchors {
                    left: parent.left
                    right: parent.right
                    top: header.bottom
                    margins: root.uniformMargin / 2
                    topMargin: 0
                }

                height: Math.min(column.implicitHeight, panel.maxHeight)
                contentHeight: column.implicitHeight
                clip: true
                interactive: flick.contentHeight > flick.height
                boundsBehavior: Flickable.StopAtBounds

                TrayMenuBranch {
                    id: column

                    width: flick.width

                    menu: TrayService.menuItem ? TrayService.menuItem.menu : null
                    uniformMargin: root.uniformMargin
                    strokeWidth: root.strokeWidth
                }
            }
        }
    }
}
