import QtQuick

import qs.config
import qs.services

// The entry point to the centre, inverted while it is open — the same treatment
// the power glyph beside it gets.
Chip {
    id: root

    visible: NotificationService.count > 0

    color: NotificationService.centerOpen ? Colors.accent : Colors.background

    ChipText {
        text: "󰛏"
        color: NotificationService.centerOpen ? Colors.background : Colors.primary
    }

    ChipText {
        visible: NotificationService.count > 0
        text: NotificationService.count
        color: NotificationService.centerOpen ? Colors.background : Colors.accent
        font.bold: NotificationService.hasCritical
    }

    overlay: MouseArea {
        anchors.fill: parent

        onClicked: NotificationService.toggleCenter()
    }
}
