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

    property string upString: "00h 00m"

    Process {
        id: upProc
        command: ["sh", "-c", "uptime -p | sed 's/up //; s/ hours,/h/; s/ hour,/h/; s/ minutes/m/; s/ minute/m/'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    root.upString = data.trim()
                }
            }
        }
    }

    Timer { interval: 30000; running: true; repeat: true; onTriggered: upProc.running = true }

    RowLayout {
        id: content
        anchors.centerIn: parent
        Text { color: Colors.accent; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: "UP" }
        Text { color: Colors.primary; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: root.upString }
    }
}