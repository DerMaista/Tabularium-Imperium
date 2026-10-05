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

    overlay: WheelArea {
        anchors.fill: parent

        onStepped: direction => AudioService.adjust(direction * AudioService.step)

        onClicked: AudioService.toggleMute()
    }
}
