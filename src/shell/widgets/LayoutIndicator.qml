import QtQuick

import qs.config
import qs.services

Chip {
    id: root

    readonly property string monitorName: root.screen.name

    // The default keymode is the normal state, so only a modal one is worth
    // drawing — and then loudly, since every keybind now means something else.
    readonly property bool modal: WorkspaceService.keymode !== "default"

    property string layout: WorkspaceService.layoutFor(root.monitorName)

    visible: WorkspaceService.available && (root.layout.length > 0 || root.modal)

    color: root.modal ? Colors.accent : Colors.background

    Connections {
        target: WorkspaceService

        function onMonitorUpdated(name) {
            if (name === root.monitorName)
                root.layout = WorkspaceService.layoutFor(root.monitorName);
        }
    }

    ChipText {
        visible: root.layout.length > 0
        text: root.layout
        color: root.modal ? Colors.background : Colors.primary
    }

    ChipText {
        visible: root.modal
        text: WorkspaceService.keymode
        color: Colors.background
        font.bold: true
    }
}
