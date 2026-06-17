import Quickshell
import QtQuick

import qs.src.globals.config
import qs.src.globals.states
import qs.src.features.bar.icons
import qs.src.features.performance
import qs.src.features.quote
import "./components"

PanelWindow {

    id: bar
    property alias powerButton: powerBtn
    property bool verticalMode: false
    property string wsMode: "roman"

    HoverPopupController {
        id: batteryPopupController
        popup: batteryPopup
        iconHovered: batteryIcon.isHovered
    }

    HoverPopupController {
        id: musicPopupController
        popup: musicPopup
        iconHovered: musicIcon.isHovered
    }

    HoverPopupController {
        id: perfPopupController
        popup: perfPopup
        iconHovered: perfIcon.isHovered
    }

    HoverPopupController {
        id: quotePopupController
        popup: quotePopup
        iconHovered: quoteIcon.isHovered
    }
    implicitHeight: (Config.bar && Config.bar.height !== undefined) ? Config.bar.height : 32
    //implicitHeight: implicitHeight
    screen: Quickshell.screens[0]

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    Rectangle {
        id: barBackground
        anchors.fill: parent
        color: {
            const surface = Colors.surface;
            if (!surface || surface === "")
                return "#00000000";
            return surface.startsWith("#") ? surface : `#${surface}`;
       }
        opacity: 0.9
        z: 0
    }

    Workspaces {
        id: workspaces
        anchors.left: bar.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 32
        z: 1
        verticalMode: bar.verticalMode
        wsMode: bar.wsMode
    }

    Layout {
        id: layout
        anchors.left: workspaces.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        z: 1
    }

    Keymode {
        id: keymode
        anchors.left: layout.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        z: 1
    }

    Clock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        z: 1
    }
/*
    Test {
        id: gitStatus
        width: 100
        anchors.right: quoteIcon.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        z: 1
        alwaysShift: true
        elided: Component {
            Text {
                text: "git status gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg"
                color: "green"
                font.pixelSize: 12
            }
        }
    }
*/
    QuoteIcon {
        id: quoteIcon
        anchors.right: batteryIcon.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        z: 1
        onTogglePopup: function(visible) {
            quotePopupController.handleToggle(visible)
        }
    }

    Connections {
        target: quotePopup
        function onIsHoveredChanged() {
            quotePopupController.handlePopupHoverChanged()
        }
    }

    BatteryIcon {
        id: batteryIcon
        anchors.right: musicIcon.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        z: 1
        onTogglePopup: function(visible) {
            batteryPopupController.handleToggle(visible)
        }
    }

    Connections {
        target: batteryPopup
        function onIsHoveredChanged() {
            batteryPopupController.handlePopupHoverChanged()
        }
    }

    MusicIcon {
        id: musicIcon
        anchors.right: perfIcon.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        z: 1
        onTogglePopup: function(visible) {
            musicPopupController.handleToggle(visible)
        }
    }

    Connections {
        target: musicPopup
        function onIsHoveredChanged() {
            musicPopupController.handlePopupHoverChanged()
        }
    }

    PerfIcon {
        id: perfIcon
        anchors.right: powerBtn.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        z: 1
        onTogglePopup: function(visible) {
            perfPopupController.handleToggle(visible)
        }
    }

    Connections {
        target: perfPopup
        function onIsHoveredChanged() {
            perfPopupController.handlePopupHoverChanged()
        }
    }

    PowerButton {
        id: powerBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        z: 1
    }
}