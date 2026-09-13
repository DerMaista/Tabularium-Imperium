import QtQuick

Item {
    id: root

    anchors.fill: parent

    required property int gridSize
    required property color gridColor
    required property real thinWidth
    required property real thickWidth

    ShaderEffect {
        anchors.fill: parent

        // Names must match the uniform block in blueprint_grid.frag; Qt binds
        // them by reflection.
        property color gridColor: root.gridColor
        property vector2d resolution: Qt.vector2d(width, height)
        property real gridSize: root.gridSize
        property real thinWidth: root.thinWidth
        property real thickWidth: root.thickWidth

        fragmentShader: Qt.resolvedUrl("../shaders/blueprint_grid.frag.qsb")
    }
}
