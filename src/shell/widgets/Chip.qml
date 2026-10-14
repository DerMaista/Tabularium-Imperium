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

    // Even padding: centerIn snaps to whole pixels, so an odd margin would push
    // the content half a pixel off center (a full device pixel on scaled outputs).
    readonly property real padding: Math.round(root.uniformMargin / 2) * 2

    readonly property real contentWidth: layout.implicitWidth + root.padding
    readonly property real contentHeight: layout.implicitHeight + root.padding

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
