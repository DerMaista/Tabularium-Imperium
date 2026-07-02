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

    property string volumeLevel: "0%"

    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2*100\"%\"}'"]
        running: true
        stdout: SplitParser { onRead: data => root.volumeLevel = data.trim() }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        Text { color: Colors.accent; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: "VOL" }
        Text { color: Colors.primary; font.pixelSize: Config.fontsize; font.family: Config.fontfamily; text: root.volumeLevel }
    }

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            let cmd = wheel.angleDelta.y > 0 ? "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            Quickshell.execDetached(["sh", "-c", cmd]);
            volProc.running = true;
        }
    }
}