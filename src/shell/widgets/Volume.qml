import QtQuick

import qs.config
import qs.services

Chip {
    id: root

    color: Colors.background

    ChipText {
        text: "VOL"
        color: Colors.accent
    }

    ChipText {
        text: {
            if (!AudioService.available)
                return "--";
            if (AudioService.muted)
                return "MUTE";
            return AudioService.percent + "%";
        }
        color: Colors.primary
    }

    overlay: MouseArea {
        anchors.fill: parent

        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? AudioService.step : -AudioService.step;
            AudioService.adjust(step);
        }

        onClicked: AudioService.toggleMute()
    }
}
