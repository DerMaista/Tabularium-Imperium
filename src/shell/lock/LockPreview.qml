pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: Colors.background
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blueshell-lock-preview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => root.handleKey(event)

        LockSurface {
            anchors.fill: parent
            screen: root.screen
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            LockService.cancelPreview();
            event.accepted = true;
        }
    }
}
