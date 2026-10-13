import QtQuick

import qs.config
import qs.services

Chip {
    id: root

    // The default keymode is the normal state, so only a modal one is worth
    // drawing — and then loudly, since every keybind now means something else.
    readonly property bool modal: WorkspaceService.keymode !== "default"

    visible: WorkspaceService.available && root.modal

    color: Colors.background

    ChipText {
        text: WorkspaceService.keymode
        color: Colors.primary
        font.bold: true
    }background
}
