pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs.config

Singleton {
    id: root

    property string kind: ""

    readonly property bool visible: root.kind !== ""

    property bool armed: false

    property real lastBrightness: -1
    property real lastVolume: -1
    property bool lastMuted: false

    function show(kind) {
        root.kind = kind;
        hideTimer.restart();
    }

    function hide() {
        hideTimer.stop();
        root.kind = "";
    }

    function syncAudio() {
        root.lastVolume = AudioService.volume;
        root.lastMuted = AudioService.muted;
    }

    function noteAudio() {
        if (!AudioService.available)
            return;

        const changed = Math.abs(AudioService.volume - root.lastVolume) > 0.0001 || AudioService.muted !== root.lastMuted;
        root.syncAudio();

        if (root.armed && changed)
            root.show("volume");
    }

    Timer {
        id: hideTimer

        interval: Config.osdTimeout

        onTriggered: root.kind = ""
    }

    Timer {
        running: true
        interval: 1500

        onTriggered: root.armed = true
    }

    Connections {
        target: BrightnessService

        function onValueChanged() {
            const changed = Math.abs(BrightnessService.value - root.lastBrightness) > 0.0001;
            root.lastBrightness = BrightnessService.value;

            if (root.armed && changed && BrightnessService.available)
                root.show("brightness");
        }
    }

    Connections {
        target: AudioService

        function onVolumeChanged() {
            root.noteAudio();
        }

        function onMutedChanged() {
            root.noteAudio();
        }

        function onSinkChanged() {
            root.syncAudio();
        }

        function onAvailableChanged() {
            root.syncAudio();
        }
    }
}
