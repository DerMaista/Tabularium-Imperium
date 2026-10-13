import QtQuick

import qs.config
import qs.services

Chip {
    id: root

    readonly property string monitorName: root.screen.name

    property string layout: WorkspaceService.layoutFor(root.monitorName)

    visible: WorkspaceService.available && root.layout.length > 0

    Connections {
        target: WorkspaceService

        function onMonitorUpdated(name) {
            if (name === root.monitorName)
                root.layout = WorkspaceService.layoutFor(root.monitorName);
        }
    }

    ChipText {
        text: root.layout
        color: Colors.primary
    }
}
