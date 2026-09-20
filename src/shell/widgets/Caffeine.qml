import QtQuick

import qs.config
import qs.services

Chip {
    id: root

    visible: CaffeineService.available

    // Filled while caffeine holds both halves; only the glyph goes accent when
    // logind refused the inhibitor, because then the screen stays awake but the
    // machine can still suspend underneath us.
    color: CaffeineService.active && !CaffeineService.partial ? Colors.accent : Colors.background

    ChipText {
        text: ""
        color: CaffeineService.active ? (CaffeineService.partial ? Colors.accent : Colors.background) : Colors.primary
    }

    overlay: MouseArea {
        anchors.fill: parent

        onClicked: CaffeineService.toggle()
    }
}
