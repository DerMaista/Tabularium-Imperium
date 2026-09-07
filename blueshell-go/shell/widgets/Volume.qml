import QtQuick
import Quickshell.Services.Pipewire

Chip {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var audio: root.sink ? root.sink.audio : null

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    ChipText {
        accent: true
        text: "VOL"
    }

    ChipText {
        text: {
            if (!root.audio)
                return "--";
            if (root.audio.muted)
                return "MUTE";
            return Math.round(root.audio.volume * 100) + "%";
        }
    }

    overlay: MouseArea {
        anchors.fill: parent

        onWheel: wheel => {
            if (!root.audio)
                return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.audio.volume = Math.max(0, Math.min(1, root.audio.volume + step));
        }

        onClicked: {
            if (root.audio)
                root.audio.muted = !root.audio.muted;
        }
    }
}
