import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.config
import qs.widgets

Scope {
    id: root

    required property var screen

    readonly property int screenw: root.screen.width
    readonly property int screenh: root.screen.height
    readonly property real uniformMargin: Math.max(Math.min(root.screenw, root.screenh) * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    readonly property int topheight: topContent.childrenRect.height + root.uniformMargin / 2

    PanelWindow {
        id: wallpaper

        screen: root.screen

        implicitWidth: root.screenw
        implicitHeight: root.screenh

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background

        color: Colors.background

        Rectangle {
            id: borderRec

            anchors.fill: parent
            anchors.margins: root.uniformMargin * 1.5

            color: "transparent"
            border.color: Colors.accent
            border.width: root.strokeWidth

            z: -1

            BlueprintGrid {
                anchors.fill: parent

                gridSize: 15
                gridColor: Colors.accent
                thinWidth: root.strokeWidth / 2
                thickWidth: root.strokeWidth
            }

            Item {
                id: centerLogo

                anchors.centerIn: parent

                readonly property real size: Math.min(parent.width, parent.height) * 0.9
                width: centerLogo.size
                height: centerLogo.size

                Image {
                    id: sourceSvg

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit

                    sourceSize.width: parent.width
                    sourceSize.height: parent.height

                    source: Qt.resolvedUrl("../svgs/Flag_of_Ecocommunist_Europe.svg")
                    visible: false
                }

                ShaderEffect {
                    x: (sourceSvg.width - sourceSvg.paintedWidth) / 2
                    y: (sourceSvg.height - sourceSvg.paintedHeight) / 2
                    width: sourceSvg.paintedWidth
                    height: sourceSvg.paintedHeight

                    property variant src: sourceSvg
                    property color primaryColor: Colors.primary
                    property color accentColor: Colors.accent

                    fragmentShader: Qt.resolvedUrl("../shaders/color_swap.frag.qsb")
                }
            }

            Item {
                id: topContent

                anchors.fill: parent

                Clock {
                    id: clock
                    screen: root.screen
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.top
                        verticalCenterOffset: root.strokeWidth / 2
                    }
                }

                Workspaces {
                    id: workspaces
                    screen: root.screen
                    anchors {
                        left: parent.left
                        verticalCenter: parent.top
                        verticalCenterOffset: root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }

                Notifications {
                    id: notifications

                    screen: root.screen
                    anchors {
                        left: workspaces.right
                        verticalCenter: parent.top
                        verticalCenterOffset: root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }

                Logout {
                    id: logout

                    screen: root.screen
                    anchors {
                        right: parent.right
                        verticalCenter: parent.top
                        verticalCenterOffset: root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }

                

                SysMonitor {
                    id: sysmon

                    screen: root.screen
                    anchors {
                        right: logout.left
                        verticalCenter: parent.top
                        verticalCenterOffset: root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }

                Storage {
                    id: storage

                    screen: root.screen
                    anchors {
                        right: sysmon.left
                        verticalCenter: parent.top
                        verticalCenterOffset: root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }

                Battery {
                    screen: root.screen
                    anchors {
                        right: storage.left
                        verticalCenter: parent.top
                        verticalCenterOffset: root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }
            }

            Item {
                id: bottomContent

                anchors.fill: parent

                Network {
                    id: network

                    screen: root.screen
                    anchors {
                        left: parent.left
                        verticalCenter: parent.bottom
                        verticalCenterOffset: -root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }

                Uptime {
                    screen: root.screen
                    anchors {
                        left: network.right
                        verticalCenter: parent.bottom
                        verticalCenterOffset: -root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }

                MprisMedia {
                    screen: root.screen
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.bottom
                        verticalCenterOffset: -root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }

                Volume {
                    screen: root.screen
                    anchors {
                        right: parent.right
                        verticalCenter: parent.bottom
                        verticalCenterOffset: -root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }
            }
        }
    }
}
