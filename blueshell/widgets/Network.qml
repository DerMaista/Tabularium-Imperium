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

    property string netName: "DISCONNECTED"

    Process {
        id: netProc
        // Depenency: iwgetid (from wireless-tools package)
        command: ["sh", "-c", "iwgetid -r || echo 'OFFLINE'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    root.netName = data.trim().toUpperCase()
                }
            }
        }
    }

    Timer { interval: 5000; running: true; repeat: true; onTriggered: netProc.running = true }

    RowLayout {
        id: content
        anchors.centerIn: parent
        Text { color: Colors.accent; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: "NET" }
        Text { color: Colors.primary; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: root.netName }
    }
}