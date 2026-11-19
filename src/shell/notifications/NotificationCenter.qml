pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services

PanelWindow {
    id: root

    required property int topheight

    readonly property real screenSize: root.screen ? Math.min(root.screen.width, root.screen.height) : 1000
    readonly property real uniformMargin: Math.max(root.screenSize * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

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
            height: Math.min(header.height + panel.contentHeight + root.uniformMargin * 2.5, keyScope.height - root.panelTop - root.uniformMargin * 2.5)

            color: Colors.background
            border {
                width: root.strokeWidth
                color: Colors.accent
            }

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

                model: NotificationService.groups

                delegate: Column {
                    id: group

                    required property var modelData

                    readonly property int total: group.modelData.notifications.length
                    readonly property bool expanded: NotificationService.isExpanded(group.modelData.key)
                    readonly property var shown: group.expanded ? group.modelData.notifications : group.modelData.notifications.slice(0, 1)

                    width: list.width
                    spacing: root.strokeWidth * 2

                    Item {
                        width: parent.width
                        height: groupName.implicitHeight

                        Text {
                            id: groupName

                            anchors.left: parent.left
                            width: Math.min(implicitWidth, parent.width - groupActions.width - groupCount.implicitWidth - root.uniformMargin)
                            text: (group.modelData.name || "UNKNOWN").toUpperCase()
                            color: Colors.accent
                            font.pixelSize: Config.fontsize - 2
                            font.family: Config.fontfamily
                            font.bold: true
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                        }

                        Text {
                            id: groupCount

                            anchors {
                                left: groupName.right
                                leftMargin: root.uniformMargin / 3
                                baseline: groupName.baseline
                            }

                            visible: group.total > 1
                            text: group.total
                            color: Colors.accent
                            opacity: 0.7
                            font.pixelSize: Config.fontsize - 3
                            font.family: Config.fontfamily
                        }

                        Row {
                            id: groupActions

                            anchors {
                                right: parent.right
                                baseline: groupName.baseline
                            }
                            spacing: root.uniformMargin / 2
                            // A Row has no text baseline of its own; without this its top
                            // edge lands on the group name's baseline and the labels slide
                            // down under the first card.
                            baselineOffset: expandLabel.baselineOffset

                            Text {
                                id: expandLabel

                                visible: group.total > 1
                                text: group.expanded ? "LESS" : "+" + (group.total - 1) + " MORE"
                                color: expandArea.containsMouse ? Colors.primary : Colors.accent
                                font.pixelSize: Config.fontsize - 3
                                font.family: Config.fontfamily

                                MouseArea {
                                    id: expandArea

                                    anchors.fill: parent
                                    anchors.margins: -root.strokeWidth * 2
                                    hoverEnabled: true

                                    onClicked: NotificationService.toggleGroup(group.modelData.key)
                                }
                            }

                            Text {
                                visible: group.total > 1
                                text: "CLEAR"
                                color: clearGroupArea.containsMouse ? Colors.primary : Colors.accent
                                font.pixelSize: Config.fontsize - 3
                                font.family: Config.fontfamily

                                MouseArea {
                                    id: clearGroupArea

                                    anchors.fill: parent
                                    anchors.margins: -root.strokeWidth * 2
                                    hoverEnabled: true

                                    onClicked: NotificationService.dismissGroup(group.modelData.key)
                                }
                            }
                        }
                    }

                    Repeater {
                        model: group.shown

                        delegate: NotificationCard {
                            required property var modelData

                            width: group.width

                            notification: modelData
                            uniformMargin: root.uniformMargin
                            strokeWidth: root.strokeWidth
                            showTime: true
                            showClose: true
                            showApp: false

                            onCloseRequested: NotificationService.dismiss(modelData)
                        }
                    }
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
