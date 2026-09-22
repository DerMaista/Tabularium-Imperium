pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services

PanelWindow {
    id: root

    readonly property real screenSize: root.screen ? Math.min(root.screen.width, root.screen.height) : 1000
    readonly property real uniformMargin: Math.max(root.screenSize * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    readonly property bool brightness: OsdService.kind === "brightness"

    readonly property bool muted: !root.brightness && AudioService.muted

    readonly property real value: root.brightness ? BrightnessService.value : AudioService.volume

    readonly property string readout: {
        if (root.muted)
            return "MUTE";
        if (!root.brightness && !AudioService.available)
            return "--";
        return Math.round(root.value * 100) + "%";
    }

    anchors {
        bottom: true
    }

    margins {
        bottom: root.uniformMargin * 5
    }

    implicitWidth: Math.max(280, Math.min(root.screen.width * 0.22, 460))
    implicitHeight: body.implicitHeight + root.uniformMargin

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blueshell-osd"

    Rectangle {
        id: card

        anchors.fill: parent

        color: Colors.background
        border {
            width: root.strokeWidth
            color: Colors.accent
        }

        opacity: 0
        Component.onCompleted: card.opacity = 1

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        ColumnLayout {
            id: body

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.uniformMargin / 2
            }
            spacing: root.uniformMargin / 2

            OsdMeter {
                Layout.fillWidth: true

                value: root.value
                strokeWidth: root.strokeWidth
                dimmed: root.muted
            }
        }
    }
}
