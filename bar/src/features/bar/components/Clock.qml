import QtQuick
import qs.src.globals.config
import qs.src.globals.states

Row {
    id: clock
    spacing: 6
    anchors.centerIn: parent
    anchors.verticalCenter: parent.verticalCenter

    Text {
        id: timeText
        color: Colors.on_surface
        font.pixelSize: 14
        font.family: "Maple Mono NF"
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
        color: Colors.on_surface_variant
        font.pixelSize: 14
        font.family: "Maple Mono NF"
        text: Qt.formatDateTime(new Date(), "ddd, dd MMM")

        Timer {
            interval: 60000
            running: true
            repeat: true
            onTriggered: dateText.text = Qt.formatDateTime(new Date(), "ddd, dd MMM")
        }
    }
}