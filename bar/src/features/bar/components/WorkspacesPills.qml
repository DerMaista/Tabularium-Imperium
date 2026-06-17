import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.src.globals.config
import qs.src.globals.states

Item {
    id: root
    height: 25
    width: pills.implicitWidth + 20

    Behavior on width {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    property bool verticalMode: false
    transform: Rotation {
        origin.x: width / 2
        origin.y: height / 2
        angle: verticalMode ? 90 : 0
    }

    property int minWorkspaces: 9
    property int currentWorkspace: activeWorkspaceId
    property int activeWorkspaceId: 1

    ListModel { id: wsModel }

    // Workspace Process - mmsg -w -t
    Process {
        id: wsProc
        command: ["sh", "-c", "mmsg -w -t"]
        running: true
        property var buffer: []

        stdout: SplitParser {
            onRead: data => {
                if (!data) return

                wsProc.buffer.push(data.trim())

                // Filter for tag lines matching: "MONITORNAME tag TAGNUM ACTIVE CLIENTS FOCUSED"
                var tagLines = wsProc.buffer.filter(line => line.match(/^\S+ tag \d+ \d+ \d+ \d+/))

                if (tagLines.length >= root.minWorkspaces) {
                    // Find max tag number
                    var maxTag = Math.max(...tagLines.map(line => parseInt(line.match(/tag (\d+)/)[1])))
                    var states = []


                    for (var i = 0; i < maxTag; i++)
                        states[i] = { active: 0, clients: 0, focused: 0 }

                    // Parse each tag line
                    for (var line of tagLines) {
                        var match = line.match(/^\S+ tag (\d+) (\d+) (\d+) (\d+)/)
                        if (match) {
                            var idx = parseInt(match[1]) - 1
                            states[idx].active = parseInt(match[2])
                            states[idx].clients = parseInt(match[3])
                            states[idx].focused = parseInt(match[4])

                            // Update active workspace from focused tag
                            if (parseInt(match[4]) === 1) {
                                activeWorkspaceId = parseInt(match[1])
                            }
                        }
                    }

                    // Update the model
                    wsModel.clear()
                    for (var i = 1; i <= maxTag; i++) {
                        wsModel.append({
                            id: i,
                            focused: states[i - 1].focused === 1,
                            active: states[i - 1].active === 1,
                            clients: states[i - 1].clients
                        })
                    }

                    wsProc.buffer = []
                }
            }
        }
    }

    Rectangle {
        id: bgRect
        opacity: 1
        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        anchors.fill: parent
        color: Colors.surface_container_low
        radius: 20
        border.color: Colors.outline
        border.width: 1
    }

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            model: wsModel

            delegate: Rectangle {
                id: pill
                width: !active && clients >= 1
                        ? 10
                        : active
                            ? 20
                            : 10
                height: 10
                radius: 20
                anchors.verticalCenter: parent.verticalCenter
                opacity: !active && clients >= 1
                        ? 0.8
                        : active
                            ? 1.0
                            : 0.4
                color: !active && clients >= 1
                        ? Colors.primary
                        : active
                            ? Colors.on_surface
                            : Colors.on_surface

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (activeWorkspaceId !== id) {
                            Quickshell.execDetached(["mmsg", "-st", String(id)])
                        }
                    }
                    onEntered: {
                        pill.scale = 1.2
                    }
                    onExited: {
                        pill.scale = 1.0
                    }
                }

                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
            }
        }
    }
}