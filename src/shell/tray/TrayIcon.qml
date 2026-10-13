import QtQuick

import qs.config

Item {
    id: root

    required property string source

    property real size: Config.fontsize * 1.2

    property color tint: Colors.primary

    // Dark parts of the icon; match whatever sits behind the icon.
    property color shade: Colors.background

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

        // Render through a layer so the shader samples the real icon texture;
        // a hidden Image never produces one.
        layer.enabled: Config.trayMonochrome
        layer.smooth: true
        layer.samplerName: "src"
        layer.effect: ShaderEffect {
            property color tintColor: root.tint
            property color shadeColor: root.shade

            fragmentShader: Qt.resolvedUrl("../shaders/tint.frag.qsb")
        }
    }
}
