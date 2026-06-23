pragma Singleton

import Quickshell.Io
import QtQuick
import Quickshell

Singleton {
    id: root

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/tabularium-imperium/config.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property JsonObject text: JsonObject {
                id: textConfig

                property string fontfamily
                property int fontsize
            }
            property JsonObject notifications: JsonObject {
                id: notificationsConfig

                property int timeout
            }
            property JsonObject bar: JsonObject {
                id: barConfig

                property int height
            }
            property JsonObject wallpaper_switcher: JsonObject {
                id: wallpaperConfig

                property string wallpaperDir
                property string wallpaperCmd
            }
        }
    }
    property alias fontfamily: textConfig.fontfamily
    property alias fontsize: textConfig.fontsize
    property alias notificationsTimeout: notificationsConfig.timeout
    property alias barHeight: barConfig.height
    property alias wallpaperDir: wallpaperConfig.wallpaperDir
    property alias wallpaperCmd: wallpaperConfig.wallpaperCmd
}