pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

import qs.config
import qs.services

Item {
    id: root

    required property real diameter

    readonly property real ringWidth: Math.max(2, root.diameter * 0.035)
    readonly property real radius: (root.diameter - root.ringWidth) / 2

    width: root.diameter
    height: root.diameter

    readonly property int tickCount: 24
    readonly property real tickStep: 360 / root.tickCount

    property real turnRaw: 0
    readonly property real turn: Math.round(root.turnRaw / root.tickStep) * root.tickStep

    Item {
        anchors.fill: parent
        rotation: root.turn

        Shape {
            id: baseRing

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            SequentialAnimation on opacity {
                running: LockService.fingerprintActive
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation {
                    to: 0.45
                    duration: 900
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1.0
                    duration: 900
                    easing.type: Easing.InOutSine
                }
            }

            ShapePath {
                strokeColor: LockService.fingerprintActive ? Colors.accent : Colors.background
                strokeWidth: root.ringWidth
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap

                Behavior on strokeColor {
                    ColorAnimation {
                        duration: 250
                    }
                }

                PathAngleArc {
                    centerX: root.diameter / 2
                    centerY: root.diameter / 2
                    radiusX: root.radius
                    radiusY: root.radius
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: LockService.arcSweep > 0
        opacity: LockService.indicatorState === "wrong" ? 1.0 : 0.9

        ShapePath {
            strokeColor: Colors.primary
            strokeWidth: root.ringWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.diameter / 2
                centerY: root.diameter / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: LockService.arcStart
                sweepAngle: LockService.arcSweep
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    Shape {
        id: statusRing

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        opacity: {
            if (LockService.indicatorState === "verifying")
                return 0.55;
            if (LockService.indicatorState === "wrong")
                return 1.0;
            return 0;
        }

        property bool failed: false

        Connections {
            target: LockService

            function onIndicatorStateChanged() {
                if (LockService.indicatorState === "wrong")
                    statusRing.failed = true;
                else if (LockService.indicatorState === "verifying")
                    statusRing.failed = false;
            }
        }

        ShapePath {
            strokeColor: statusRing.failed ? Colors.contrast : Colors.primary
            strokeWidth: root.ringWidth
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.diameter / 2
                centerY: root.diameter / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: root.diameter * 0.02

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ClockService.time
            color: Colors.primary
            font.pixelSize: root.diameter * 0.22
            font.family: Config.fontfamily
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ClockService.date.toUpperCase()
            color: Colors.accent
            font.pixelSize: root.diameter * 0.06
            font.family: Config.fontfamily
        }
    }
}
