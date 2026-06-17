import QtQuick
import Quickshell
import qs.src.components.icons

AnimatedIcon {
    id: musicIcon
    icon: "󰎆"
    iconSize: 28
    
    signal togglePopup(bool visible)
    
    onHovered: function(hovered) {
        musicIcon.togglePopup(hovered)
    }
}