import QtQuick
import qs.src.components.panels
import qs.src.globals.states

PanelHeader {
    id: notificationHeader
    title: "Notifications"
    showActionButton: false
    property bool showCloseButton: false

    signal closeClicked()

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: notificationHeader.showCloseButton
        radius: ThemeManager.radiusSmall
        color: Colors.surface_container_high
        width: 28
        height: 28

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: Colors.on_surface
            font.family: ThemeManager.fontFamily
            font.pixelSize: ThemeManager.fontSizeMedium
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: notificationHeader.closeClicked()
        }
    }
}