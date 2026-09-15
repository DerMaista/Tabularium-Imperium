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

    overlay: MouseArea {
        anchors.fill: parent

        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? BrightnessService.step : -BrightnessService.step;
            BrightnessService.adjust(step);
        }
    }
}
