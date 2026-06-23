import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

import qs.config

Item {
    id: hexItem

    property real hexRadius: 600
    property string wallpaperPath: ""

    implicitWidth: hexRadius * 2
    implicitHeight: Math.ceil(hexRadius * 1.73205)

    readonly property real _r: hexRadius
    readonly property real _cx: _r
    readonly property real _cy: implicitHeight / 2
    readonly property real _cos30: 0.866025
    readonly property real _sin30: 0.5
    property bool isHovered: false

    Item {
        id: hexMask
        width: hexItem.implicitWidth; height: hexItem.implicitHeight
        visible: false
        layer.enabled: true
        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "white"
                strokeColor: "transparent"
                startX: hexItem._cx + hexItem._r;                          startY: hexItem._cy
                PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30;  y: hexItem._cy - hexItem._r * hexItem._cos30 }
                PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30;  y: hexItem._cy - hexItem._r * hexItem._cos30 }
                PathLine { x: hexItem._cx - hexItem._r;                   y: hexItem._cy }
                PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30;  y: hexItem._cy + hexItem._r * hexItem._cos30 }
                PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30;  y: hexItem._cy + hexItem._r * hexItem._cos30 }
                PathLine { x: hexItem._cx + hexItem._r;                   y: hexItem._cy }
            }
        }
    }

    Loader {
        id: _imageLoader
        width: hexItem.implicitWidth
        height: hexItem.implicitHeight
        active: true
        visible: false
        layer.enabled: active

        property bool imgReady: _imageLoader.item && _imageLoader.item.status === Image.Ready

        sourceComponent: Image {
          id: wallpaperImage
            anchors.fill: parent
            source: hexItem.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    Item {
        id: imageOverlay
        anchors.fill: parent
        visible: _imageLoader.active && _imageLoader.status === Loader.Ready
        opacity: hexItem.pulledOut ? 0 : 1

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: _imageLoader
            live: true
        }

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: hexMask
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
        }
    }

    Shape {
        anchors.fill: parent
        visible: true
        opacity: hexItem.pulledOut ? 1 : 0
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: hexItem.colors ? Config.surface : Qt.rgba(1,1,1,0.05)
            strokeColor: hexItem.colors ? Qt.rgba(hexItem.colors.primary.r, hexItem.colors.primary.g, hexItem.colors.primary.b, 0.4) : Qt.rgba(1,1,1,0.2)
            strokeWidth: 2
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]
            startX: hexItem._cx + hexItem._r;                          startY: hexItem._cy
            PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30;  y: hexItem._cy - hexItem._r * hexItem._cos30 }
            PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30;  y: hexItem._cy - hexItem._r * hexItem._cos30 }
            PathLine { x: hexItem._cx - hexItem._r;                   y: hexItem._cy }
            PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30;  y: hexItem._cy + hexItem._r * hexItem._cos30 }
            PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30;  y: hexItem._cy + hexItem._r * hexItem._cos30 }
            PathLine { x: hexItem._cx + hexItem._r;                   y: hexItem._cy }
        }
    }

    Shape {
        id: hexBorder
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        visible: _imageLoader.active && _imageLoader.imgReady
        ShapePath {
            fillColor: "transparent"
            strokeColor: hexItem.isHovered
                ? Colors.primary
                : Colors.secondary
            strokeWidth: hexItem.isHovered ? 3 : 1.5
            startX: hexItem._cx + hexItem._r;                          startY: hexItem._cy
            PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30;  y: hexItem._cy - hexItem._r * hexItem._cos30 }
            PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30;  y: hexItem._cy - hexItem._r * hexItem._cos30 }
            PathLine { x: hexItem._cx - hexItem._r;                   y: hexItem._cy }
            PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30;  y: hexItem._cy + hexItem._r * hexItem._cos30 }
            PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30;  y: hexItem._cy + hexItem._r * hexItem._cos30 }
            PathLine { x: hexItem._cx + hexItem._r;                   y: hexItem._cy }
        }
    }
}