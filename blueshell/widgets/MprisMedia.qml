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

    property string trackInfo: "NO MEDIA ACTIVE"

    Process {
        id: mediaProc
        command: ["playerctl", "metadata", "--format", "{{artist}} - {{title}}"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if(data) root.trackInfo = data.trim()
            }
        }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: mediaProc.running = true }

    RowLayout {
        id: content
        anchors.centerIn: parent
        Text {
            color: Colors.primary; font.pixelSize: Config.fontsize; font.family: Config.fontfamily
            text: root.trackInfo.length > 30 ? root.trackInfo.substring(0, 27) + "..." : root.trackInfo
        }
    }
}