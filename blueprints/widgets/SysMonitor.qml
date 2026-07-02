import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

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

    property string cpuUsage: "00%"
    property string ramUsage: "00%"

    Process {
        id: sysProc
        command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}'; free -m | awk '/Mem:/ {printf \"%.0f%%\", $3/$2 * 100}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                if (data.includes("%")) {
                    root.ramUsage = data.trim()
                } else {
                    root.cpuUsage = Math.round(parseFloat(data)).toString() + "%"
                }
            }
        }
    }

    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: sysProc.running = true
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 12

        Text { color: Colors.accent; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: "CPU" }
        Text { color: Colors.primary; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: root.cpuUsage }
        Text { color: Colors.accent; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: "• RAM" }
        Text { color: Colors.primary; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: root.ramUsage }
    }
}