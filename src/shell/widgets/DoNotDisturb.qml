import QtQuick

import qs.config
import qs.services

Chip {
    id: root

    color: NotificationService.dnd ? Colors.accent : Colors.background

    ChipText {
        text: NotificationService.dnd ? "󰂛" : "󰂚"
        color: NotificationService.dnd ? Colors.background : Colors.primary
    }

    overlay: MouseArea {
        anchors.fill: parent

        onClicked: NotificationService.toggleDnd()
    }
}
