import QtQuick

import qs.config
import qs.services

Chip {
    id: root

    visible: PowerService.available
    implicitWidth: PowerService.available ? root.contentWidth : 0
    implicitHeight: PowerService.available ? root.contentHeight : 0

    color: PowerService.panelOpen ? Colors.accent : Colors.background

    ChipText {
        text: ""
        color: PowerService.panelOpen ? Colors.background : Colors.primary
    }

    overlay: MouseArea {
        anchors.fill: parent
        onClicked: PowerService.togglePanel()
    }
}
