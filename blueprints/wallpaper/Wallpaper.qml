// Wallpaper.qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Effects

import qs.config
import qs.widgets

Scope {
    id: root

    required property var screen

    property int screenw: screen.width
    property int screenh: screen.height
    property real uniformMargin: Math.max(Math.min(screenw, screenh) * 0.01, 15 )
    property real strokeWidth: uniformMargin / 6

    property int topheight: topContent.childrenRect.height + uniformMargin / 2

    PanelWindow {
        id: wallpaper
        screen: root.screen

        implicitWidth: screenw
        implicitHeight: screenh

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background

        color: Colors.background

        Rectangle {
            id: borderRec
            anchors.fill: parent
            anchors.centerIn: parent
            anchors.margins: root.uniformMargin * 1.5

            color: "transparent"

            border.color: Colors.accent
            border.width: root.strokeWidth

            z: -1

            BlueprintGrid {
                id: grid
                anchors.fill: parent

                gridSize: 15
                gridColor: Colors.accent
                thinWidth: root.strokeWidth / 2
                thickWidth: root.strokeWidth
            }

            Item {
                id: centerLogo

                anchors.centerIn: parent
                property real size: Math.min(parent.width, parent.height) * 0.9
                width: size
                height: size

                Image {
                    id: sourceSvg
                    anchors.fill: parent

                    fillMode: Image.PreserveAspectFit

                    sourceSize.width: parent.width
                    sourceSize.height: parent.height

                    source: Qt.resolvedUrl("../svgs/enterprise.svg")
                    visible: false
                }

                ShaderEffect {
                    id: effectItem
                    x: sourceSvg.transparentProxy ? 0 : (sourceSvg.width - sourceSvg.paintedWidth) / 2
                    y: sourceSvg.transparentProxy ? 0 : (sourceSvg.height - sourceSvg.paintedHeight) / 2
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
                    screen: root.screen
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.top
                        verticalCenterOffset: root.strokeWidth / 2
                    }
                }
                Workspaces {
                    screen: root.screen
                    anchors {
                        left: parent.left
                        verticalCenter: parent.top
                        verticalCenterOffset: root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }
                SysMonitor {
                    id: sysmon
                    screen: root.screen
                    anchors {
                        right: parent.right
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

                Volume {
                    screen: root.screen
                    anchors {
                        right: parent.right
                        verticalCenter: parent.bottom
                        verticalCenterOffset: -root.strokeWidth / 2
                        margins: root.uniformMargin
                    }
                }
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
                        verticalCenterOffset: -root.strokeWidth / 21
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
            }
        }
    }
}