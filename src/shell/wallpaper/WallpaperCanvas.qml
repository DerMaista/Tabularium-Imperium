pragma ComponentBehavior: Bound

import QtQuick

import qs.config
import qs.services

Item {
    id: root

    required property var screen

    property bool showSigil: true
    property bool showChips: true

    property bool interactive: true

    readonly property real screenw: root.screen ? root.screen.width : root.width
    readonly property real screenh: root.screen ? root.screen.height : root.height
    readonly property real uniformMargin: Math.max(Math.min(root.screenw, root.screenh) * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    property real topheight: 0

    // Two image buffers: the new wallpaper loads hidden and fades in over the current one, never dropping to the sigil.
    readonly property var buffers: [imageA, imageB]
    property int front: 0
    readonly property Image frontImage: root.buffers[root.front]

    readonly property url target: WallpaperService.showImage && WallpaperService.image.length > 0 ? WallpaperService.source : ""

    // Image layer opacity: 1 over grid and sigil, 0 in sigil mode; cross-fades only once the new image has loaded.
    property bool layerOnScreen: false
    onImageOpacityChanged: root.layerOnScreen = root.imageOpacity > 0
    readonly property bool imageShown: WallpaperService.showImage && root.frontImage.status === Image.Ready && (root.frontImage.source == root.target || root.layerOnScreen)
    property real imageOpacity: root.imageShown ? 1 : 0

    // Startup: show only the background until the backend says what to draw and,
    // in image mode, the image has loaded; then appear without a fade.
    readonly property bool settled: WallpaperService.known && SigilService.known && (!WallpaperService.showImage || root.targetDone(imageA) || root.targetDone(imageB))

    function targetDone(image) {
        return image.source == root.target && (image.status === Image.Ready || image.status === Image.Error);
    }
    property bool animate: false
    onSettledChanged: if (root.settled)
        Qt.callLater(() => root.animate = true)
    readonly property real sigilOpacity: root.settled ? 1 - root.imageOpacity : 0

    Behavior on imageOpacity {
        enabled: root.animate && Config.colorAnimDuration > 0

        NumberAnimation {
            duration: Config.colorAnimDuration
            easing.type: Config.colorAnimEasing
            easing.bezierCurve: Config.colorAnimBezier
        }
    }

    onTargetChanged: root.loadTarget()
    Component.onCompleted: root.loadTarget()

    // Sigil mode keeps the last image loaded, so it can fade straight back in.
    function loadTarget() {
        if (root.target == "")
            return;
        const current = root.frontImage;
        if (current.source == root.target && current.status !== Image.Error)
            return;
        const back = root.buffers[1 - root.front];
        if (back.source == root.target && back.status === Image.Ready) {
            root.swap();
            return;
        }
        // Same path after an error: clear first so the image really reloads.
        back.source = "";
        back.source = root.target;
    }

    function bufferStatusChanged(index) {
        const image = root.buffers[index];
        if (index !== root.front && image.status === Image.Ready && image.source == root.target)
            root.swap();
    }

    function swap() {
        const back = 1 - root.front;
        // The outgoing image stays fully opaque underneath, even mid-fade.
        fadeIn.stop();
        root.frontImage.opacity = 1;
        root.buffers[back].opacity = 0;
        root.front = back;
        // With no image on screen, the layer fade (imageOpacity) is the transition.
        if (root.imageOpacity > 0 && Config.colorAnimDuration > 0)
            fadeIn.restart();
        else
            root.buffers[back].opacity = 1;
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.background
    }

    Item {
        id: imageLayer

        anchors.fill: parent
        opacity: root.settled ? root.imageOpacity : 0
        visible: opacity > 0

        WallpaperImage {
            id: imageA

            z: root.front === 0 ? 1 : 0
            sourceSize.width: root.screenw
            sourceSize.height: root.screenh
            onStatusChanged: root.bufferStatusChanged(0)
        }

        WallpaperImage {
            id: imageB

            z: root.front === 1 ? 1 : 0
            sourceSize.width: root.screenw
            sourceSize.height: root.screenh
            onStatusChanged: root.bufferStatusChanged(1)
        }
    }

    NumberAnimation {
        id: fadeIn

        target: root.frontImage
        property: "opacity"
        from: 0
        to: 1
        duration: Config.colorAnimDuration
        easing.type: Config.colorAnimEasing
        easing.bezierCurve: Config.colorAnimBezier
    }

    // Retry an image that failed to load (same path, so nothing else reloads it).
    Connections {
        target: WallpaperService

        function onUpdated() {
            if (root.target != "" && root.frontImage.source == root.target && root.frontImage.status === Image.Error)
                root.loadTarget();
        }
    }

    component WallpaperImage: Image {
        anchors.fill: parent

        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        anchors.margins: root.uniformMargin * 1.5

        color: "transparent"
        border.color: Colors.accent
        border.width: root.strokeWidth

        BlueprintGrid {
            anchors.fill: parent
            opacity: root.sigilOpacity
            visible: opacity > 0

            gridSize: 15
            gridColor: Colors.accent
            thinWidth: root.strokeWidth / 2
            thickWidth: root.strokeWidth
        }

        Item {
            id: centerLogo

            anchors.centerIn: parent
            opacity: root.sigilOpacity
            visible: root.showSigil && opacity > 0

            readonly property real size: Math.min(parent.width, parent.height) * 0.5
            width: centerLogo.size
            height: centerLogo.size

            Image {
                id: sourceSvg

                anchors.fill: parent
                fillMode: Image.PreserveAspectFit

                sourceSize.width: parent.width
                sourceSize.height: parent.height

                source: SigilService.source != "" ? SigilService.source : Qt.resolvedUrl("../svgs/NixOS.svg")
                visible: false
            }

            ShaderEffect {
                x: (sourceSvg.width - sourceSvg.paintedWidth) / 2
                y: (sourceSvg.height - sourceSvg.paintedHeight) / 2
                width: sourceSvg.paintedWidth
                height: sourceSvg.paintedHeight

                property variant src: sourceSvg
                property color primaryColor: Colors.primary
                property color accentColor: Colors.secondary

                fragmentShader: Qt.resolvedUrl("../shaders/color_swap.frag.qsb")
            }
        }
    }

    Loader {
        id: chipsLoader

        anchors.fill: parent
        anchors.margins: root.uniformMargin * 1.5

        active: root.showChips
        sourceComponent: chipsComponent
    }

    Component {
        id: chipsComponent

        WallpaperChips {
            id: chips

            screen: root.screen
            enabled: root.interactive

            onTopheightChanged: root.topheight = chips.topheight
            Component.onCompleted: root.topheight = chips.topheight
        }
    }
}
