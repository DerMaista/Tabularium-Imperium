import QtQuick

import Quickshell.Services.Pipewire

import qs.config

Chip {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var audio: root.sink ? root.sink.audio : null

    readonly property bool muted: root.audio ? root.audio.muted : false

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    // Inverted while muted, the same way Notifications marks an open centre.
    color: Colors.background

    ChipText {
        text: "VOL"
        color: Colors.accent
    }

    ChipText {
        text: {
            if (!root.audio)
                return "--";
            if (root.muted)
                return "MUTE";
            return Math.round(root.audio.volume * 100) + "%";
        }
        color: Colors.primary
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
