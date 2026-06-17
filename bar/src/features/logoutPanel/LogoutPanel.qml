import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.src.globals.config
import qs.src.globals.states

PanelWindow {
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    id: logoutPanel
    visible: false


    required property QtObject bar


    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Colors.surface_variant
        opacity: 0.9
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                logoutPanel.visible = false
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (logoutPanel.bar && logoutPanel.bar.powerButton) {
                    logoutPanel.bar.powerButton.isActive = false
                    logoutPanel.bar.powerButton.scaleFactor = 1.0
                }
                logoutPanel.visible = false
            }
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 40

            Repeater {
                model: buttonModel

                delegate: Rectangle {
                    width: 100
                    height: 100
                    radius: 50
                    color: hovered ? Colors.primary : Colors.surface
                    border.color: Colors.outline

                    property bool hovered: false

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onClicked: {
                            runCommand(modelData.action)
                            logoutPanel.visible = false
                            if (logoutPanel.bar && logoutPanel.bar.powerButton) {
                                logoutPanel.bar.powerButton.isActive = false
                                logoutPanel.bar.powerButton.scaleFactor = 1.0
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        font.pixelSize: 40
                        color: parent.hovered ? Colors.on_primary : Colors.on_surface
                    }
                }
            }
        }
    }

    property var buttonModel: [
        { icon: "", action: "swaylock" }, // Lock
        { icon: "", action: "systemctl reboot" },                      // Reboot
        { icon: "", action: "systemctl poweroff" },                    // Shutdown
        { icon: "", action: "loginctl kill-session $XDG_SESSION_ID" }, // Logout
        { icon: "", action: "systemctl suspend" },                     // Suspend
        { icon: "󰒲", action: "systemctl hibernate" }                   // Hibernate
    ]

    function runCommand(cmd) {
        try {
            Qt.createQmlObject(
                'import Quickshell.Io; Process { command: ["bash","-c","' + cmd + '"]; running: true }',
                logoutPanel
            )
        } catch (e) {
            console.log("Failed to run:", cmd, e)
        }
    }

    IpcHandler {
        target: "logout_panel_ipc"
        function toggle(): void { logoutPanel.visible = !logoutPanel.visible }
    }
}