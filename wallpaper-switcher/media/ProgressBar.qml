import QtQuick
import qs.states
Rectangle {
    id: progressBar
    height: 4
    radius: 2
    color: Colors.outline

    property real progress: 0.0 // 0.0 to 1.0
    property color fillColor: Colors.primary

    signal seekRequested(real position) // 0.0 to 1.0

    Rectangle {
        width: parent.width * Math.min(Math.max(progressBar.progress, 0), 1)
        height: parent.height
        radius: 2
        color: progressBar.fillColor

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            var seekPos = mouseX / parent.width
            progressBar.seekRequested(seekPos)
        }
    }
}