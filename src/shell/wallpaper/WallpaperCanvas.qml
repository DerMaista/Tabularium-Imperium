pragma ComponentBehavior: Bound

import QtQuick

import qs.config
import qs.services

Item {
    id: root

    required property var screen

    property bool showSigil: true
    property bool showChips: true

    property bool interactive: true

    readonly property real screenw: root.screen ? root.screen.width : root.width
    readonly property real screenh: root.screen ? root.screen.height : root.height
    readonly property real uniformMargin: Math.max(Math.min(root.screenw, root.screenh) * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    property real topheight: 0

    Rectangle {
        anchors.fill: parent
        color: Colors.background
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        anchors.margins: root.uniformMargin * 1.5

        color: "transparent"
        border.color: Colors.accent
        border.width: root.strokeWidth

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
            visible: root.showSigil

            readonly property real size: Math.min(parent.width, parent.height) * 0.9
            width: centerLogo.size
            height: centerLogo.size

            Image {
                id: sourceSvg

                anchors.fill: parent
                fillMode: Image.PreserveAspectFit

                sourceSize.width: parent.width
                sourceSize.height: parent.height

                source: SigilService.source != "" ? SigilService.source : Qt.resolvedUrl("../svgs/NixOS.svg")
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
    }

    Loader {
        id: chipsLoader

        anchors.fill: parent
        anchors.margins: root.uniformMargin * 1.5

        active: root.showChips
        sourceComponent: chipsComponent
    }

    Component {
        id: chipsComponent

        WallpaperChips {
            id: chips

            screen: root.screen
            enabled: root.interactive

            onTopheightChanged: root.topheight = chips.topheight
            Component.onCompleted: root.topheight = chips.topheight
        }
    }
}
