pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

import qs.config
import qs.services
import qs.wallpaper

Item {
    id: root

    required property var screen

    readonly property real screenSize: root.screen ? Math.min(root.screen.width, root.screen.height) : 1000
    readonly property real uniformMargin: Math.max(root.screenSize * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    readonly property real dialSize: Math.min(root.screenSize * 0.34, 420)

    readonly property bool closed: LockService.panesClosed

    readonly property bool joined: LockService.dialJoined

    WallpaperCanvas {
        anchors.fill: parent

        screen: root.screen
        showSigil: true
        showChips: true
    }

    component Pane: Item {
        id: pane

        required property bool leftSide

        width: Math.ceil(root.width / 2)
        height: root.height

        clip: true

        property real slide: 0

        x: pane.leftSide ? (pane.slide - 1) * pane.width : root.width - pane.slide * pane.width

        NumberAnimation {
            id: slideAnim

            target: pane
            property: "slide"
            duration: LockService.paneDuration
            easing.type: Easing.OutCubic
        }

        Component.onCompleted: pane.slide = root.closed ? 1 : 0

        Connections {
            target: root

            function onClosedChanged() {
                slideAnim.stop();
                slideAnim.from = pane.slide;
                slideAnim.to = root.closed ? 1 : 0;
                slideAnim.start();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Shape {
            preferredRendererType: Shape.CurveRenderer
            visible: !root.joined

            width: root.dialSize
            height: root.dialSize
            x: pane.leftSide ? pane.width - root.dialSize / 2 : -root.dialSize / 2
            y: (pane.height - root.dialSize) / 2

            ShapePath {
                strokeColor: Colors.accent
                strokeWidth: Math.max(2, root.dialSize * 0.035)
                fillColor: "transparent"

                PathAngleArc {
                    centerX: root.dialSize / 2
                    centerY: root.dialSize / 2
                    radiusX: (root.dialSize - Math.max(2, root.dialSize * 0.035)) / 2
                    radiusY: (root.dialSize - Math.max(2, root.dialSize * 0.035)) / 2
                    startAngle: pane.leftSide ? 90 : 270
                    sweepAngle: 180
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: 0.8

        Pane {
            leftSide: true
        }

        Pane {
            leftSide: false
        }

    }

    LockDial {
        anchors.centerIn: parent

        diameter: root.dialSize
        visible: root.joined
    }
}
