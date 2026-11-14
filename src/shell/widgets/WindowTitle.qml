import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services

Chip {
    id: root

    readonly property string monitorName: root.screen.name

    readonly property var window: WorkspaceService.focusFor(root.monitorName)
    readonly property string title: root.window ? (root.window.title || root.window.appId || "") : ""

    // The monitor holding keyboard focus shows its window at full strength;
    // the others keep naming their last window, dimmed.
    readonly property bool focused: WorkspaceService.focusedMonitor === root.monitorName

    // Set by the bar so a long title never runs into the clock.
    property real maximumWidth: Infinity

    readonly property bool shown: WorkspaceService.focusAvailable && root.title.length > 0 && root.maximumWidth > root.padding + Config.fontsize * 4

    visible: root.shown
    implicitWidth: root.shown ? Math.min(root.contentWidth, root.maximumWidth) : 0
    implicitHeight: root.shown ? root.contentHeight : 0

    ChipText {
        Layout.maximumWidth: Math.max(0, root.maximumWidth - root.padding)

        text: root.title
        opacity: root.focused ? 1 : 0.6
        elide: Text.ElideRight
        maximumLineCount: 1
        textFormat: Text.PlainText
    }
}
