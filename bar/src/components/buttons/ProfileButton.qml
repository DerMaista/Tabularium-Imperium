import QtQuick
import QtQuick.Layouts

import qs.src.globals.states
import qs.src.globals.config

Rectangle {
    id: profileButton
    Layout.fillWidth: true
    Layout.preferredHeight: 40
    radius: 8
    
    property string profile: ""
    property string icon: "?"
    property string tooltip: ""
    property bool isSelected: false
    
    signal clicked()
    
    color: profileButton.isSelected ? Colors.primary : Colors.surface_variant
    border.color: profileButton.isSelected ? Colors.primary : Colors.outline
    border.width: 2

    RowLayout {
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: profileButton.icon
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            color: profileButton.isSelected ? Colors.on_primary : Colors.on_surface_variant
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: profileButton.clicked()
    }
}