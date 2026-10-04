import QtQuick
import QtQuick.Effects

import qs.config

Item {
    id: root

    required property string source

    property real size: Config.fontsize * 1.2

    property color tint: Colors.primary

    implicitWidth: root.size
    implicitHeight: root.size

    Image {
        id: image

        anchors.fill: parent

        source: root.source
        asynchronous: true
        smooth: true
        fillMode: Image.PreserveAspectFit
        sourceSize.width: root.size
        sourceSize.height: root.size

        visible: !Config.trayMonochrome
    }

    MultiEffect {
        anchors.fill: parent

        visible: Config.trayMonochrome
        source: image
        colorization: 1
        colorizationColor: root.tint
    }
}
