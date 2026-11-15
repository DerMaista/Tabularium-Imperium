import QtQuick

import qs.config
import qs.services

// Shown inverted while the microphone, camera or screen records; clicking names the applications.
Chip {
    id: root

    readonly property bool shown: PrivacyService.active

    property bool expanded: false

    onShownChanged: {
        if (!root.shown)
            root.expanded = false;
    }

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
        visible: root.expanded && root.apps.length > 0
        text: root.apps
        color: Colors.background
        textFormat: Text.PlainText
    }

    overlay: MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }
}
