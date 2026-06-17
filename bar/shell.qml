import Quickshell
import QtQuick

import qs.src.features.bar
import qs.src.features.notificationPanel
import qs.src.features.logoutPanel
import qs.src.features.performance
import qs.src.popups.power
import qs.src.popups.music
import qs.src.popups.reload
import qs.src.features.quote
import qs.src.osd

Scope {
    id: root
    property QtObject activeBar: null

    ReloadPopup {
        id: reloadPopup
    }
    LogoutPanel {
        id: logoutPanel
        bar: root.activeBar
    }
    Variants {
        model: Quickshell.screens
        Bar {
            id: bar
            required property var modelData
            screen: modelData
            Component.onCompleted: root.activeBar = bar
        }
    }
    BatteryPopup {
        id: batteryPopup
        bar: root.activeBar
    }
    MusicPopup {
        id: musicPopup
        bar: root.activeBar
    }
    PerformancePopup {
        id: perfPopup
        bar: root.activeBar
    }
    NotificationPanel {
        id: notifPanel
    }
    QuotePopup {
        id: quotePopup
        bar: root.activeBar
    }
    VolumeOSD {
        id: volumeOSD
    }
    BrightnessOSD {
        id: brightnessOSD
    }
}