pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/tabularium-imperium"

    readonly property color targetBackground: adapter.background
    readonly property color targetPrimary: adapter.primary
    readonly property color targetAccent: adapter.accent

    property color background: root.targetBackground
    property color primary: root.targetPrimary
    property color accent: root.targetAccent

    property bool loadedOnce: false

    readonly property bool animating: root.loadedOnce && Config.colorAnimDuration > 0

    Behavior on background {
        enabled: root.animating

        ColorAnimation {
            duration: Config.colorAnimDuration
            easing.type: Config.colorAnimEasing
            easing.bezierCurve: Config.colorAnimBezier
        }
    }

    Behavior on primary {
        enabled: root.animating

        ColorAnimation {
            duration: Config.colorAnimDuration
            easing.type: Config.colorAnimEasing
            easing.bezierCurve: Config.colorAnimBezier
        }
    }

    Behavior on accent {
        enabled: root.animating

        ColorAnimation {
            duration: Config.colorAnimDuration
            easing.type: Config.colorAnimEasing
            easing.bezierCurve: Config.colorAnimBezier
        }
    }

    FileView {
        id: file

        path: root.configDir + "/colors.json"
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        onLoaded: root.loadedOnce = true
        onLoadFailed: root.loadedOnce = true

        JsonAdapter {
            id: adapter

            property string background: "#0040a1"
            property string primary: "#d9fdff"
            property string accent: "#2872cf"
        }
    }
}
