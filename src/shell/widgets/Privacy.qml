import QtQuick

import qs.config
import qs.services

// Shown only while something records: microphone, camera or screen. Drawn
// inverted so it is hard to miss; hovering names the applications.
Chip {
    id: root

    readonly property bool shown: PrivacyService.active

    readonly property string apps: {
        const names = [];
        for (const list of [PrivacyService.micApps, PrivacyService.cameraApps, PrivacyService.screencastApps]) {
            for (const name of list) {
                if (names.indexOf(name) === -1)
                    names.push(name);
            }
        }
        return names.join(", ");
    }

    visible: root.shown
    implicitWidth: root.shown ? root.contentWidth : 0
    implicitHeight: root.shown ? root.contentHeight : 0

    color: Colors.accent

    ChipText {
        visible: PrivacyService.micActive
        text: "󰍬"
        color: Colors.background
    }

    ChipText {
        visible: PrivacyService.cameraActive
        text: "󰖠"
        color: Colors.background
    }

    ChipText {
        visible: PrivacyService.screencastActive
        text: "󱒃"
        color: Colors.background
    }

    ChipText {
        visible: hover.containsMouse && root.apps.length > 0
        text: root.apps
        color: Colors.background
        textFormat: Text.PlainText
    }

    overlay: MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
    }
}
