import QtQuick

import qs.services

Chip {
    id: root

    visible: BrightnessService.available

    ChipText {
        accent: true
        text: "BRT"
    }

    ChipText {
        text: BrightnessService.percent + "%"
    }

    overlay: WheelArea {
        anchors.fill: parent

        onStepped: direction => BrightnessService.adjust(direction * BrightnessService.step)
    }
}
