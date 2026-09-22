pragma ComponentBehavior: Bound

import QtQuick

import qs.config

Item {
    id: root

    required property real value

    required property real strokeWidth

    property int segments: 20

    property bool dimmed: false

    readonly property real clamped: Math.max(0, Math.min(1, root.value))

    readonly property int filled: Math.round(root.clamped * root.segments)

    readonly property real segmentStroke: Math.max(1, root.strokeWidth / 2)

    implicitHeight: Config.fontsize

    opacity: root.dimmed ? 0.4 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }

    Row {
        anchors.fill: parent
        spacing: root.strokeWidth

        Repeater {
            model: root.segments

            delegate: Rectangle {
                required property int index

                width: (root.width - root.strokeWidth * (root.segments - 1)) / root.segments
                height: root.height

                color: index < root.filled ? Colors.primary : "transparent"
                border {
                    width: root.segmentStroke
                    color: Colors.accent
                }
            }
        }
    }
}
