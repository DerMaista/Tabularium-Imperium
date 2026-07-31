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

    Variants {
        id: wallpaperVariants
        model: Quickshell.screens

        Scope {
            id: monitor
            required property var modelData

            Wallpaper {
                id: wallpaper
                screen: monitor.modelData
            }

            Border {
                id: border
                topheight: wallpaper.topheight
                screen: monitor.modelData
            }
        }
    }
}