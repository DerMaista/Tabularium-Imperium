// Clock.qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts

import qs.config



Rectangle {
    id: clock

    required property var screen

    property int screenw: screen.width
    property int screenh: screen.height
    property real uniformMargin: Math.max(Math.min(screenw, screenh) * 0.01, 15 )
    property real strokeWidth: uniformMargin / 6

    color: Colors.background

    border {
        width: strokeWidth
        color: Colors.accent
    }

    implicitWidth: content.implicitWidth + uniformMargin
    implicitHeight: content.implicitHeight + uniformMargin

    RowLayout {
        id: content
        anchors.centerIn: parent

        Text {
            id: timeText
            color: Colors.primary
            font.pixelSize: Config.fontsize
            font.family: Config.fontfamily
            text: Qt.formatDateTime(new Date(), "HH:mm")

            Timer {
                interval: 60000
                running: true
                repeat: true
                onTriggered: timeText.text = Qt.formatDateTime(new Date(), "HH:mm")
            }
        }

        Text {
            id: dateText
            color: Colors.primary
            font.pixelSize: Config.fontsize
            font.family: Config.fontfamily
            text: Qt.formatDateTime(new Date(), "ddd, dd MMM")

            Timer {
                interval: 60000
                running: true
                repeat: true
                onTriggered: dateText.text = Qt.formatDateTime(new Date(), "ddd, dd MMM")
            }
        }
    }
}