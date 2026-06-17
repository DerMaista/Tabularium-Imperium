import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.src.components.panels
import qs.src.globals.states

PopupWindow {
    id: perfPopup
    visible: false
    implicitWidth: 600
    implicitHeight: 240  // Increased height for speedometer needles
    color: "transparent"
    property bool isHovered: popupHoverHandler.hovered
    property QtObject bar: null

    anchor.window: bar
    anchor.rect.x: bar ? bar.width : 0
    anchor.rect.y: bar ? bar.height : 0

    HoverHandler {
        id: popupHoverHandler
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 12
        spacing: 30

        SpeedometerGauge {
            id: cpuGauge
            label: "CPU"
            value: 0
            maxValue: 100
            Layout.preferredWidth: 160
            Layout.preferredHeight: 160
        }

        SpeedometerGauge {
            id: ramGauge
            label: "RAM" 
            value: 0
            maxValue: 100
            Layout.preferredWidth: 160
            Layout.preferredHeight: 160
        }

        SpeedometerGauge {
            id: diskGauge
            label: "DISK"
            value: 0
            maxValue: 100
            Layout.preferredWidth: 160
            Layout.preferredHeight: 160
        }
    }

    // Performance data process
    Process {
        id: perfProc
        command: ["hydractl", "perf"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "") {
                    Qt.callLater(() => perfProc.running = true)
                    return
                }
                try {
                    var data = JSON.parse(this.text.trim())
                    cpuGauge.value = parseFloat(data.cpu) || 0
                    ramGauge.value = parseFloat(data.ram) || 0
                    diskGauge.value = parseFloat(data.disk) || 0
                } catch(e) {
                    console.log("hydractl perf parse error", e, "RAW OUTPUT:", this.text)
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: perfPopup.visible
        repeat: true
        onTriggered: perfProc.running = true
    }

    Component.onCompleted: perfProc.running = true
}