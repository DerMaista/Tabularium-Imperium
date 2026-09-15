pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.services

PanelWindow {
    id: root

    readonly property var entries: LockService.flyoutEntries.filter(entry => entry.monitor === root.screen.name)

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-lock-flyout"

    Item {
        id: content

        anchors.fill: parent

        opacity: 0

        LockEffects {
            anchors.fill: parent

            screen: root.screen
        }

        ScreencopyView {
            id: capture

            anchors.fill: parent

            captureSource: root.screen
            live: false
            paintCursor: false

            onStopped: console.warn("lock: screen capture stopped on " + root.screen.name)

            onHasContentChanged: {
                if (!hasContent)
                    return;

                content.opacity = 1;
                shot.scheduleUpdate();
                LockService.noteCaptured();
            }
        }

        ShaderEffectSource {
            id: shot

            anchors.fill: parent

            sourceItem: capture
            live: false
            hideSource: false
            visible: false
        }

        NumberAnimation {
            id: captureFade

            target: capture
            property: "opacity"
            to: 0
            duration: Math.min(280, LockService.flyDuration)
            easing.type: Easing.InQuad
        }

        Repeater {
            id: copies

            model: root.entries

            delegate: WindowCopy {
                required property var modelData
                required property int index

                readonly property real relX: modelData.x - root.screen.x
                readonly property real relY: modelData.y - root.screen.y

                atlas: shot
                atlasW: capture.width
                atlasH: capture.height

                homeX: relX
                homeY: relY
                homeW: modelData.width
                homeH: modelData.height
                stagger: index * LockService.staggerStep
            }
        }
    }

    Connections {
        target: LockService

        function onFadeIn() {
            for (let i = 0; i < copies.count; i++) {
                const copy = copies.itemAt(i);
                if (copy)
                    copy.fadeIn(LockService.flyDuration);
            }
        }

        function onFlyOut() {
            content.opacity = 1;
            captureFade.start();

            for (let i = 0; i < copies.count; i++) {
                const copy = copies.itemAt(i);
                if (copy)
                    copy.fadeOut(LockService.flyDuration);
            }
        }
    }
}
