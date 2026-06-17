import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io
import qs.src.components.panels
import qs.src.components.media
import qs.src.globals.config
import qs.src.globals.states
PopupWindow {
    id: batteryPopup
    visible: false
    implicitWidth: 320
    implicitHeight: hasBattery ? 200 : 160
    property bool isHovered: popupHoverHandler.hovered
    property QtObject bar: null

    anchor.window: bar
    anchor.rect.x: bar ? (bar.width - width) : 0
    anchor.rect.y: bar ? bar.height : 0

    property bool hasBattery: false
    property string currentProfile: "balanced"

    onVisibleChanged: {
        if (visible) {
            updatePowerProfile()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 12
        spacing: 12

        // Header
        Text {
            text: hasBattery ? "Battery" : "Power"
            font.pixelSize: 18
            font.bold: true
            font.family: ThemeManager.fontFamily
            color: Colors.on_surface
        }

        // Battery info (only show if battery exists)
        ColumnLayout {
            visible: hasBattery
            Layout.fillWidth: true
            spacing: 8

            ProgressBar {
                id: batteryLevel
                progress: 0.0
                Layout.fillWidth: true

                fillColor: Colors.primary;

            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    id: batteryPercentage
                    font.pixelSize: 14
                    font.bold: true
                    font.family: ThemeManager.fontFamily
                    color: Colors.primary
                }

                Text {
                    id: batteryStatus
                    font.pixelSize: 14
                    font.family: ThemeManager.fontFamily
                    color: Colors.on_surface_variant
                    Layout.fillWidth: true
                }

                Text {
                    id: batteryIcon
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.on_surface_variant
                }
            }
        }

        // Desktop message (when no battery)
        Text {
            visible: !hasBattery
            text: "󰌶 Desktop Mode"
            font.pixelSize: 14
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.on_surface_variant
            Layout.alignment: Qt.AlignHCenter
        }

        // Power profile controls
        PowerProfileSelector {
            currentProfile: batteryPopup.currentProfile
            onProfileSelected: function(profile) {
                setPowerProfile(profile)
            }
        }
    }

    HoverHandler {
        id: popupHoverHandler
    }

    Process {
        id: profileProcess
        command: ["hydractl", "power", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var profile = this.text.trim().toLowerCase()

                if (profile === "performance") {
                    currentProfile = "performance"
                } else if (profile === "power-saver") {
                    currentProfile = "power-saver"
                } else {
                    currentProfile = "balanced"
                }
            }
        }
    }

    function updateBatteryInfo() {
        var dev = UPower.displayDevice
        hasBattery = !!dev

        if (dev) {
            batteryLevel.progress = dev.percentage
            batteryPercentage.text = dev.percentage.toFixed(2) * 100 + "%"

            var stateStr = dev.state === UPowerDeviceState.Charging ? "Charging" :
                          dev.state === UPowerDeviceState.FullyCharged ? "Full" : "Discharging"
            batteryStatus.text = stateStr

            // Update battery icon
            if (dev.state === UPowerDeviceState.Charging) {
                batteryIcon.text = ""
            } else if (dev.percentage > 0.8) {
                batteryIcon.text = ""
            } else if (dev.percentage > 0.6) {
                batteryIcon.text = ""
            } else if (dev.percentage > 0.4) {
                batteryIcon.text = ""
            } else if (dev.percentage > 0.2) {
                batteryIcon.text = ""
            } else {
                batteryIcon.text = ""
            }
        }
    }

    function updatePowerProfile() {
        profileProcess.running = true
    }

    function setPowerProfile(profile) {
        Quickshell.execDetached(["hydractl", "power", "set", profile])
        currentProfile = profile
    }

    Component.onCompleted: {
        updateBatteryInfo()
        updatePowerProfile()
    }
    Timer {
        interval: 1000
        running: batteryPopup.visible
        repeat: true
        onTriggered: updateBatteryInfo()
    }
}