import QtQuick
import QtQuick.Layouts

import qs.config

Rectangle {
    id: root

    required property var screen

    default property alias content: layout.data

    property alias overlay: overlayItem.data

    property alias spacing: layout.spacing

    readonly property real uniformMargin: Math.max(Math.min(root.screen.width, root.screen.height) * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    color: Colors.background
    border {
        width: root.strokeWidth
        color: Colors.accent
    }

    readonly property real contentWidth: layout.implicitWidth + root.uniformMargin
    readonly property real contentHeight: layout.implicitHeight + root.uniformMargin

    implicitWidth: root.contentWidth
    implicitHeight: root.contentHeight

    data: [
        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: 5
        },
        Item {
            id: overlayItem

            anchors.fill: parent
        }
    ]
}
