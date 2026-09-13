pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services

// The history panel. Built like the shell's other two overlays — full-screen,
// exclusive keyboard focus, Escape or a click outside closes it — but the panel
// itself sits where the toasts do, so opening it reads as the corner stack
// unfolding rather than as a separate dialog appearing.
PanelWindow {
    id: root

    required property int topheight

    readonly property real screenSize: root.screen ? Math.min(root.screen.width, root.screen.height) : 1000
    readonly property real uniformMargin: Math.max(root.screenSize * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    // Where the panel starts and how tall it may get. Named rather than read
    // back off the anchors group, so the height binding below does not depend
    // on the same anchors it sits next to.
    readonly property real panelTop: root.topheight + root.uniformMargin / 2

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blueshell-notification-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => root.handleKey(event)

        MouseArea {
            anchors.fill: parent

            onClicked: NotificationService.closeCenter()
        }

        Rectangle {
            id: panel

            anchors {
                top: parent.top
                left: parent.left
                topMargin: root.panelTop
                leftMargin: root.uniformMargin * 2.5
            }

            width: Math.max(320, Math.min(keyScope.width * 0.2, 420))
            readonly property real contentHeight: NotificationService.count === 0 ? emptyLabel.implicitHeight + root.uniformMargin : list.contentHeight
            // Shrinks to the content while it fits, then clamps — which is also
            // what stops the clamp from feeding back into ListView.contentHeight.
            height: Math.min(header.height + panel.contentHeight + root.uniformMargin * 2.5, keyScope.height - root.panelTop - root.uniformMargin * 2.5)

            color: Colors.background
            border {
                width: root.strokeWidth
                color: Colors.accent
            }

            // Swallows clicks that would otherwise reach the close-on-outside
            // area behind the panel.
            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: header

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: root.uniformMargin / 2
                }
                height: title.implicitHeight

                Text {
                    id: title

                    anchors.left: parent.left
                    text: "NOTIFICATIONS"
                    color: Colors.primary
                    font.pixelSize: Config.fontsize
                    font.family: Config.fontfamily
                    font.bold: true
                }

                Text {
                    anchors {
                        left: title.right
                        leftMargin: root.uniformMargin / 3
                        baseline: title.baseline
                    }

                    visible: NotificationService.count > 0
                    text: NotificationService.count
                    color: Colors.accent
                    opacity: 0.8
                    font.pixelSize: Config.fontsize - 3
                    font.family: Config.fontfamily
                }

                Text {
                    anchors.right: parent.right

                    visible: NotificationService.count > 0
                    text: "CLEAR ALL"
                    color: clearArea.containsMouse ? Colors.primary : Colors.accent
                    font.pixelSize: Config.fontsize - 2
                    font.family: Config.fontfamily

                    MouseArea {
                        id: clearArea

                        anchors.fill: parent
                        anchors.margins: -root.strokeWidth * 2
                        hoverEnabled: true

                        onClicked: NotificationService.clearAll()
                    }
                }
            }

            Text {
                id: emptyLabel

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: header.bottom
                    topMargin: root.uniformMargin
                }

                visible: NotificationService.count === 0
                text: "NOTHING TO SHOW"
                color: Colors.accent
                opacity: 0.5
                font.pixelSize: Config.fontsize - 1
                font.family: Config.fontfamily
            }

            // A ListView rather than the original's ScrollView-and-Repeater:
            // history runs to `historyLimit` rows, and only the handful on
            // screen need to exist.
            ListView {
                id: list

                anchors {
                    left: parent.left
                    right: parent.right
                    top: header.bottom
                    bottom: parent.bottom
                    margins: root.uniformMargin / 2
                    topMargin: root.uniformMargin / 2
                }

                clip: true
                spacing: root.uniformMargin / 2
                boundsBehavior: Flickable.StopAtBounds

                model: NotificationService.history

                delegate: NotificationCard {
                    required property var modelData

                    width: list.width

                    notification: modelData
                    uniformMargin: root.uniformMargin
                    strokeWidth: root.strokeWidth
                    showTime: true
                    showClose: true

                    onCloseRequested: NotificationService.dismiss(modelData)
                }
            }
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            NotificationService.closeCenter();
            event.accepted = true;
        }
    }
}
