import Quickshell.Services.UPower

Chip {
    id: root

    readonly property var mainBattery: UPower.displayDevice
    readonly property bool hasBattery: !!root.mainBattery && root.mainBattery.isLaptopBattery

    visible: root.hasBattery
    implicitWidth: root.hasBattery ? root.contentWidth : 0
    implicitHeight: root.hasBattery ? root.contentHeight : 0

    ChipText {
        accent: true
        text: {
            if (!root.mainBattery)
                return "BAT";
            return root.mainBattery.state === UPowerDeviceState.Discharging ? "BAT" : "CHG";
        }
    }

    ChipText {
        text: root.mainBattery ? Math.round(root.mainBattery.percentage * 100) + "%" : "0%"
    }
}
