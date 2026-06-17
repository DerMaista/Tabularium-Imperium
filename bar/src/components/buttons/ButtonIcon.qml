import QtQuick
import qs.src.globals.states
import qs.src.globals.config

Rectangle {
    id: iconButton
    width: 40
    height: 40
    radius: 8
    
    property string icon: "?"
    property string tooltip: ""
    property bool isPrimary: false
    property bool enabled: true
    
    signal clicked()
    
    color: {
        if (!enabled) return Colors.surface_variant
        return mouseArea.containsMouse ? 
            (isPrimary ? Colors.primary_container : Colors.surface_container) : 
            (isPrimary ? Colors.primary : Colors.surface_variant)
    }
    
    border.color: isPrimary ? Colors.primary : Colors.outline
    border.width: 2

    Text {
        anchors.centerIn: parent
        text: iconButton.icon
        font.pixelSize: 18
        font.family: "JetBrainsMono Nerd Font"
        color: isPrimary ? Colors.on_primary : Colors.on_surface_variant
        opacity: iconButton.enabled ? 1.0 : 0.5
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: iconButton.enabled
        onClicked: iconButton.clicked()
    }
}