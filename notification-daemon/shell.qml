import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.config

Scope {
    id: root
    property bool centerOpen: false
    ListModel { id: history }

    NotificationServer {
        id: server
        
        actionsSupported: true
        bodySupported: true
        imageSupported: true

        onNotification: n => {
            history.insert(0, {
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                urgency: n.urgency,
                time: Qt.formatTime(new Date(), "HH:mm")
            })
            n.tracked = true
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.centerOpen = !root.centerOpen }
        function show(): void { root.centerOpen = true }
        function hide(): void { root.centerOpen = false }
    }

    PanelWindow {
        anchors { 
            top: true
            right: true
        }
        margins { 
            top: 12 + Config.barHeight
            right: 12
        }

        implicitWidth: 380
        implicitHeight: Math.max(1, column.implicitHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 10

            Repeater {
                model: server.trackedNotifications

                delegate: Rectangle {
                    id: card
                    required property var modelData

                    Timer {
                        running: card.modelData.urgency !== NotificationUrgency.Critical
                        interval: Config.notificationsTimeout
                        onTriggered: card.modelData.dismiss()
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: layout.implicitHeight + 20

                    radius: 0
                    color: Colors.background
                    border.width: 2
                    border.color: modelData.urgency === NotificationUrgency.Critical
                        ? Colors.error : Colors.primary
                    
                    RowLayout {
                        id: layout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Image {
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: 36
                            fillMode: Image.PreserveAspectFit
                            visible: source.toString() !== ""
                            source: card.modelData.image || card.modelData.appIcon || ""
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                color: Colors.secondary
                                font.family: Config.fontfamily
                                font.pixelSize: Config.fontsize
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: card.modelData.body
                                color: Colors.on_background
                                font.family: Config.fontfamily
                                font.pixelSize: Config.fontsize - 1
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.modelData.dismiss()
                    }
                }
            }
        }
    }

    PanelWindow {
        visible: root.centerOpen
        anchors { 
            top: true
            right: true
        }
        margins { 
            top: 12 + Config.barHeight
            right: 12
        }

        implicitWidth: 380
        implicitHeight: Math.min(500, contentCol.implicitHeight + 24)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: Colors.background
            border.width: 2
            border.color: Colors.primary

            ColumnLayout {
                id: contentCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                ColumnLayout {
                    id: centerCol
                    Layout.fillWidth: true
                    Layout.column: 0
                    anchors.margins: 12
                    spacing: 10
                    
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "Notifications"
                            color: Colors.secondary
                            font.family: Config.fontfamily
                            font.pixelSize: Config.fontsize
                            font.bold: true
                        }
                        Text {
                            text: "Clear All"
                            visible: history.count > 0
                            color: Colors.error
                            font.family: Config.fontfamily
                            font.pixelSize: Config.fontsize - 1
                            MouseArea {
                                anchors.fill: parent
                                onClicked: history.clear()
                            }
                        }
                    }
                }
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    contentWidth: availableWidth

                    ColumnLayout {
                        id: cardCol
                        Layout.fillWidth: true
                        Layout.column: 1
                        anchors.margins: 12
                        spacing: 10
                        width: parent.width

                        Repeater {
                            model: history

                            delegate: Rectangle {
                                id: card
                                required property var modelData

                                Layout.fillWidth: true
                                width: cardCol.width
                                Layout.preferredHeight: layout.implicitHeight + 20

                                radius: 0
                                color: Colors.background
                                border.width: 2
                                border.color: modelData.urgency === NotificationUrgency.Critical
                                    ? Colors.error : Colors.primary
                                
                                RowLayout {
                                    id: layout
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Text {
                                                Layout.fillWidth: true
                                                text: card.modelData.summary
                                                color: Colors.secondary
                                                font.family: Config.fontfamily
                                                font.pixelSize: Config.fontsize
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: card.modelData.time
                                                color: Colors.tertiary
                                                font.family: Config.fontfamily
                                                font.pixelSize: Config.fontsize - 3
                                            }
                                            Text {
                                                text: "x"
                                                color: Colors.error
                                                font.family: Config.fontfamily
                                                font.pixelSize: Config.fontsize - 1
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: history.remove(card.modelData.index)
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                            text: card.modelData.body
                                            color: Colors.on_background
                                            font.family: Config.fontfamily
                                            font.pixelSize: Config.fontsize - 1
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            visible: card.modelData.appName !== ""
                                            text: card.modelData.appName
                                            color: Colors.tertiary
                                            font.family: Config.fontfamily
                                            font.pixelSize: Config.fontsize - 3
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}