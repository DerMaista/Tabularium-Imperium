import QtQuick

import qs.config
import qs.services

Chip {
    id: root

    readonly property bool performance: ProfileService.active === "performance"

    visible: ProfileService.available

    color: Colors.background

    ChipText {
        text: {
            switch (ProfileService.active) {
            case "power-saver":
                return "󰌪";
            case "performance":
                return "󰓅";
            default:
                return "󰾅";
            }
        }
        color: Colors.primary
    }

    overlay: WheelArea {
        anchors.fill: parent

        onClicked: ProfileService.cycle()
        onStepped: direction => ProfileService.step(direction)
    }
}
