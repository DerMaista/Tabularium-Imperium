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

    property string diskPercent: "00%"

    Process {
        id: dfProc
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $5}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    root.diskPercent = data.trim()
                }
            }
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        Text { color: Colors.accent; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: "SDD" }
        Text { color: Colors.primary; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: root.diskPercent }
    }
}