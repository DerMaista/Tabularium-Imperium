pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

import qs.config

Item {
    id: root

    required property real diameter

    readonly property real ringWidth: Math.max(1.5, root.diameter * 0.012)
    readonly property real discSize: Math.max(6, root.diameter * 0.055)

    property real secondAngle: 0
    property real minuteAngle: 0
    property real hourAngle: 0

    width: root.diameter
    height: root.diameter

    // Targets the angle one tick ahead so the linear sweep lands on the real time.
    function update() {
        const d = new Date(Date.now() + tick.interval);
        const s = d.getSeconds() + d.getMilliseconds() / 1000;
        const m = d.getMinutes() + s / 60;
        const h = d.getHours() % 12 + m / 60;
        root.secondAngle = s * 6;
        root.minuteAngle = m * 6;
        root.hourAngle = h * 30;
    }

    Timer {
        id: tick

        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible

        onTriggered: root.update()
    }

    component Ring: Item {
        id: ring

        required property real radius
        required property real angle

        anchors.fill: parent
        rotation: ring.angle

        Behavior on rotation {
            RotationAnimation {
                duration: tick.interval
                direction: RotationAnimation.Clockwise
            }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Colors.accent
                strokeWidth: root.ringWidth
                fillColor: "transparent"

                PathAngleArc {
                    centerX: root.diameter / 2
                    centerY: root.diameter / 2
                    radiusX: ring.radius
                    radiusY: ring.radius
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        Rectangle {
            x: (root.diameter - root.discSize) / 2
            y: root.diameter / 2 - ring.radius - root.discSize / 2
            width: root.discSize
            height: root.discSize
            radius: root.discSize / 2
            color: Colors.accent
        }
    }

    Ring {
        radius: root.diameter * 0.38
        angle: root.hourAngle
    }

    Ring {
        radius: root.diameter * 0.29
        angle: root.minuteAngle
    }

    Ring {
        radius: root.diameter * 0.20
        angle: root.secondAngle
    }
}
