pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var audio: root.sink ? root.sink.audio : null

    readonly property bool available: !!root.audio

    readonly property real volume: root.audio ? root.audio.volume : 0

    readonly property int percent: Math.round(root.volume * 100)

    readonly property bool muted: root.audio ? root.audio.muted : false

    readonly property real step: 0.05

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function set(value) {
        if (!root.audio)
            return;

        root.audio.volume = Math.max(0, Math.min(1, value));
    }

    function adjust(delta) {
        root.set(root.volume + delta);
    }

    function toggleMute() {
        if (!root.audio)
            return;

        root.audio.muted = !root.audio.muted;
    }
}
