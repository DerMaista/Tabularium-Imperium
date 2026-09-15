import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.config

Scope {
    id: root

    required property var screen

    readonly property int screenw: root.screen.width
    readonly property int screenh: root.screen.height

    readonly property int topheight: canvas.topheight

    PanelWindow {
        id: wallpaper

        screen: root.screen

        implicitWidth: root.screenw
        implicitHeight: root.screenh

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background

        color: Colors.background

        WallpaperCanvas {
            id: canvas

            anchors.fill: parent

            screen: root.screen
        }
    }
}
