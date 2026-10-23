pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
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

    readonly property real dialSize: root.screenSize * 0.34
    readonly property real dialRingWidth: Math.max(2, root.dialSize * 0.035)

    readonly property bool closed: LockService.panesClosed

    readonly property bool joined: LockService.dialJoined

    WallpaperCanvas {
        id: wallpaper

        anchors.fill: parent

        screen: root.screen
        showSigil: true
        showChips: true
    }

    // Limits the blur to a disc around the dial, so it only separates the rings from the sigil.
    Shape {
        id: blurMask

        anchors.fill: parent
        visible: false
        layer.enabled: true

        ShapePath {
            strokeColor: "transparent"

            fillGradient: RadialGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                centerRadius: root.dialSize * 0.65
                focalX: root.width / 2
                focalY: root.height / 2

                GradientStop {
                    position: 0.0
                    color: "white"
                }
                GradientStop {
                    position: 0.75
                    color: "white"
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }

            PathPolyline {
                path: [Qt.point(0, 0), Qt.point(root.width, 0), Qt.point(root.width, root.height), Qt.point(0, root.height), Qt.point(0, 0)]
            }
        }
    }

    MultiEffect {
        id: paneBlur

        anchors.fill: parent

        source: wallpaper
        autoPaddingEnabled: false

        blurEnabled: true
        blur: 1.0
        blurMax: 64

        maskEnabled: true
        maskSource: blurMask
        maskSpreadAtMin: 1.0
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
                if (LockService.snapPanes) {
                    pane.slide = root.closed ? 1 : 0;
                    return;
                }
                slideAnim.from = pane.slide;
                slideAnim.to = root.closed ? 1 : 0;
                slideAnim.start();
            }
        }

        // Screen-aligned slice of the blurred wallpaper, so it stays put while the pane slides.
        ShaderEffectSource {
            x: -pane.x
            width: root.width
            height: root.height

            sourceItem: paneBlur
            hideSource: true
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.8
        }

        Shape {
            preferredRendererType: Shape.CurveRenderer
            visible: !root.joined
            opacity: 0.8

            width: root.dialSize
            height: root.dialSize
            x: pane.leftSide ? pane.width - root.dialSize / 2 : -root.dialSize / 2
            y: (pane.height - root.dialSize) / 2

            ShapePath {
                strokeColor: Colors.background
                strokeWidth: root.dialRingWidth
                fillColor: "transparent"

                PathAngleArc {
                    centerX: root.dialSize / 2
                    centerY: root.dialSize / 2
                    radiusX: (root.dialSize - root.dialRingWidth) / 2
                    radiusY: (root.dialSize - root.dialRingWidth) / 2
                    startAngle: pane.leftSide ? 90 : 270
                    sweepAngle: 180
                }
            }
        }
    }

    Pane {
        leftSide: true
    }

    Pane {
        leftSide: false
    }

    LockDial {
        anchors.centerIn: parent

        diameter: root.dialSize
        visible: root.joined
    }
}
