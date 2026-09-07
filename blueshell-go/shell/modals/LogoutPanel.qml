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

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blueshell-logout-panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => root.handleKey(event)

        Rectangle {
            anchors.fill: parent
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: PowerService.closePanel()
            }
        }

        Rectangle {
            id: panel

            anchors.centerIn: parent

            width: Math.min(keyScope.width * 0.6, 760)
            implicitHeight: layout.implicitHeight + root.uniformMargin * 2

            color: Colors.background
            border {
                width: root.strokeWidth
                color: Colors.accent
            }

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: layout

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: root.uniformMargin
                }
                spacing: root.uniformMargin

                Item {
                    width: parent.width
                    height: title.implicitHeight

                    Text {
                        anchors.right: parent.right
                        color: Colors.accent
                        opacity: 0.6
                        font.pixelSize: Config.fontsize
                        font.family: Config.fontfamily
                        text: {
                            if (PowerService.busy)
                                return "WORKING…";
                            if (PowerService.loading)
                                return "LOADING…";
                            if (PowerService.error.length > 0)
                                return "ERROR";
                            return "";
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: PowerService.error.length > 0
                    text: PowerService.error
                    color: Colors.primary
                    font.pixelSize: Config.fontsize
                    font.family: Config.fontfamily
                    wrapMode: Text.Wrap
                }

                Row {
                    width: parent.width
                    spacing: root.uniformMargin

                    Repeater {
                        model: PowerService.actions

                        delegate: Rectangle {
                            id: cell

                            required property int index
                            required property var modelData

                            readonly property bool isAvailable: PowerService.actionAvailable(cell.modelData.id)
                            readonly property bool isSelected: cell.index === PowerService.selectedIndex

                            readonly property real side: (layout.width - root.uniformMargin * (PowerService.actions.length - 1)) / PowerService.actions.length

                            width: cell.side
                            height: cell.side

                            color: cell.isSelected ? Colors.accent : Colors.background
                            border {
                                width: cell.isSelected ? root.strokeWidth * 2 : root.strokeWidth
                                color: cell.isSelected ? Colors.primary : Colors.accent
                            }

                            opacity: {
                                if (!cell.isAvailable)
                                    return 0.35;
                                return PowerService.busy ? 0.5 : 1.0;
                            }

                            Behavior on border.width {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: root.uniformMargin / 3

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cell.modelData.icon
                                    color: cell.isSelected ? Colors.background : Colors.primary
                                    font.pixelSize: Config.fontsize * 2.2
                                    font.family: Config.fontfamily
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: cell.isAvailable
                                hoverEnabled: true

                                onEntered: PowerService.selectedIndex = cell.index
                                onExited: {
                                    if (PowerService.selectedIndex === cell.index)
                                        PowerService.selectedIndex = -1;
                                }
                                onClicked: PowerService.invoke(cell.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            PowerService.closePanel();
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_Tab:
            PowerService.moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            PowerService.moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            PowerService.activateSelected();
            event.accepted = true;
            break;
        }
    }
}
