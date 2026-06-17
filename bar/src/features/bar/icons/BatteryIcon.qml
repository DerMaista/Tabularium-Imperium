import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io
import qs.src.globals.config
import qs.src.globals.states
import qs.src.components.icons

StatusIcon {
    id: batteryIcon
    icon: ""
    iconSize: 24
    updateInterval: 2000

    signal togglePopup(bool visible)

    onHovered: function(hovered) {
        batteryIcon.togglePopup(hovered)
    }

    statusUpdateFunction: updateBatteryInfo

    function updateBatteryInfo() {
        var dev = UPower.displayDevice
        if (!dev) {
            batteryIcon.icon = ""
            return
        }

        var pct = dev.percentage
        var state = dev.state

        if (state === UPowerDeviceState.Charging) batteryIcon.icon = ""
        else if (pct > 0.8) batteryIcon.icon = ""
        else if (pct > 0.6) batteryIcon.icon = ""
        else if (pct > 0.4) batteryIcon.icon = ""
        else if (pct > 0.2) batteryIcon.icon = ""
        else batteryIcon.icon = ""
    }

    Component.onCompleted: updateBatteryInfo()
}