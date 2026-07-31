import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config

Rectangle {
    id: root
    required property var screen
    property real uniformMargin: Math.max(Math.min(screen.width, screen.height) * 0.01, 15)
    property real strokeWidth: uniformMargin / 6

    color: Colors.background
    border { width: strokeWidth; color: Colors.accent }
    implicitWidth: content.implicitWidth + uniformMargin
    implicitHeight: content.implicitHeight + uniformMargin

    property var mainBattery: UPower.displayDevice

    property string statusString: {
        if (!root.mainBattery) return "OMG error";

        switch (root.mainBattery.state) {
            case UPowerDeviceState.Discharging: return "BAT";
            default: return "CHG";
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent

        Text {
            color: Colors.accent
            font.pixelSize: Config.fontsize
            font.family: Config.fontfamily
            text: root.statusString
        }

        Text {
            color: Colors.primary
            font.pixelSize: Config.fontsize
            font.family: Config.fontfamily
            // 3. Print out the correct, matching percentage variable
            text: root.mainBattery ? Math.round(root.mainBattery.percentage * 100) + "%" : "0%"
        }
    }
}