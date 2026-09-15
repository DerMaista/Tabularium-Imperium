pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services

PanelWindow {
    id: root

    required property int topheight

    readonly property real screenSize: root.screen ? Math.min(root.screen.width, root.screen.height) : 1000
    readonly property real uniformMargin: Math.max(root.screenSize * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.topheight + root.uniformMargin / 2
        right: root.uniformMargin * 2.5
    }

    implicitWidth: Math.max(320, Math.min(root.screen.width * 0.2, 420))
    implicitHeight: Math.max(1, column.implicitHeight)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blueshell-notification-popups"

    ColumnLayout {
        id: column

        width: parent.width
        spacing: root.uniformMargin / 2

        Repeater {
            model: NotificationService.visiblePopups

            delegate: NotificationCard {
                required property var modelData

                Layout.fillWidth: true

                notification: modelData
                uniformMargin: root.uniformMargin
                strokeWidth: root.strokeWidth
                clickable: true

                onClicked: NotificationService.hidePopup(modelData.id)
            }
        }

        Text {
            Layout.fillWidth: true

            visible: NotificationService.hiddenPopupCount > 0
            text: "+" + NotificationService.hiddenPopupCount + " MORE"
            color: Colors.accent
            opacity: 0.7
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Config.fontsize - 3
            font.family: Config.fontfamily
        }
    }
}
