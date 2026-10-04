pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Column {
    id: root

    property QsMenuHandle menu: null

    property real uniformMargin: 15
    property real strokeWidth: 2

    property int depth: 0

    spacing: 0

    QsMenuOpener {
        id: opener

        menu: root.menu
    }

    Repeater {
        model: opener.children

        delegate: TrayMenuEntry {
            required property QsMenuEntry modelData

            width: root.width

            entry: modelData
            uniformMargin: root.uniformMargin
            strokeWidth: root.strokeWidth
            depth: root.depth
        }
    }
}
