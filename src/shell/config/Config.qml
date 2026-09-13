pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/tabularium-imperium"

    property alias fontfamily: textConfig.fontfamily
    property alias fontsize: textConfig.fontsize
    property alias notificationsTimeout: notificationsConfig.timeout
    property alias notificationsHistoryLimit: notificationsConfig.historyLimit
    property alias notificationsPopupLimit: notificationsConfig.popupLimit
    property alias barHeight: barConfig.height
    property alias wallpaperDir: wallpaperConfig.wallpaperDir
    property alias wallpaperCmd: wallpaperConfig.wallpaperCmd

    readonly property int colorAnimDuration: Math.max(0, animConfig.colorDuration)

    readonly property int colorAnimEasing: {
        if (root.hasCustomBezier)
            return Easing.Bezier;
        return root.easingType(animConfig.colorEasing);
    }

    readonly property bool hasCustomBezier: {
        const points = animConfig.colorBezier;
        return !!points && points.length >= 4;
    }

    readonly property var colorAnimBezier: {
        if (!root.hasCustomBezier)
            return [0.25, 0.1, 0.25, 1.0, 1.0, 1.0];
        const p = animConfig.colorBezier;
        return [p[0], p[1], p[2], p[3], 1.0, 1.0];
    }

    function easingType(name) {
        const value = Easing[name];
        if (typeof value === "number")
            return value;
        console.warn("Config: unknown easing curve \"" + name + "\", falling back to OutCubic");
        return Easing.OutCubic;
    }

    FileView {
        id: file

        path: root.configDir + "/config.json"
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property JsonObject text: JsonObject {
                id: textConfig

                property string fontfamily: "monospace"
                property int fontsize: 14
            }

            property JsonObject notifications: JsonObject {
                id: notificationsConfig

                property int timeout: 5000
                property int historyLimit: 100
                property int popupLimit: 5
            }

            property JsonObject bar: JsonObject {
                id: barConfig

                property int height: 35
            }

            property JsonObject animation: JsonObject {
                id: animConfig

                property int colorDuration: 400
                property string colorEasing: "OutCubic"
                property var colorBezier: []
            }

            property JsonObject theme: JsonObject {
                id: themeConfig

                property string command: ""
                property string configFile: ""
                property string templateFile: ""
                property string templatesDir: ""
            }

            property JsonObject power: JsonObject {
                id: powerConfig

                property string lockCommand: "swaylock"
            }

            property JsonObject wallpaper_switcher: JsonObject {
                id: wallpaperConfig

                property string wallpaperDir
                property string wallpaperCmd
            }
        }
    }
}
