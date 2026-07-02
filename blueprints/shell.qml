// Shell.qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.wallpaper
import qs.border

Scope {
    id: root

    Wallpaper {
        id: wallpaper
        screen: Quickshell.screens[0]
    }

    Border {
        id: border
        topheight: wallpaper.topheight
        screen: Quickshell.screens[0]
    }
}