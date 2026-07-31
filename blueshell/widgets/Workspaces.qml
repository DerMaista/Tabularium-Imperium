// Workspaces.qml
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import qs.config

Rectangle {
    id: root

    required property var screen

    property int currentWorkspace: activeWorkspaceId
    property int activeWorkspaceId: 1

    property int screenw: screen.width
    property int screenh: screen.height
    property real uniformMargin: Math.max(Math.min(screenw, screenh) * 0.01, 15 )
    property real strokeWidth: uniformMargin / 6

    implicitWidth: content.implicitWidth + uniformMargin
    implicitHeight: content.implicitHeight + uniformMargin

    color: Colors.background

    border {
        width: strokeWidth
        color: Colors.accent
    }






    ListModel { id: wsModel }

    function toRomanDigit(n) {
        const map = {
            1: "I",
            2: "II",
            3: "III",
            4: "IV",
            5: "V",
            6: "VI",
            7: "VII",
            8: "VIII",
            9: "IX"
        };

        return map[n] ?? null;
    }


    function toJapDigit(n) {
        const map = {
            1: "一",
            2: "二",
            3: "三",
            4: "四",
            5: "五",
            6: "六",
            7: "七",
            8: "八",
            9: "九"
        };

        return map[n] ?? null;
    }

    // Workspace Process - mmsg watch all-tags
    Process {
        id: wsProc
        command: ["mmsg", "watch", "all-tags"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                if (!data) return

                var parsed
                try {
                    parsed = JSON.parse(data)
                } catch (e) {
                    return
                }

                var monitor = parsed.all_tags.find(m => m.monitor === root.screen.name)
                if (!monitor) return

                wsModel.clear()
                for (var tag of monitor.tags) {
                    wsModel.append({
                        id: tag.index,
                        active: tag.is_active,
                        clients: tag.client_count
                    })

                    if (tag.is_active) {
                        activeWorkspaceId = tag.index
                    }
                }
            }
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            model: wsModel

            delegate: Text {
                id: number



                text: toRomanDigit(model.id)
                anchors.verticalCenter: parent.verticalCenter
                opacity: !active && clients >= 1
                        ? 1.0
                        : active
                            ? 1.0
                            : 0.4
                color: !active && clients >= 1
                        ? Colors.accent
                        : active
                            ? Colors.primary
                            : Colors.accent

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
                            Quickshell.execDetached(["mmsg", "dispatch", `view,${id},0`])
                        }
                    }
                    onEntered: {
                        number.scale = 1.2
                    }
                    onExited: {
                        number.scale = 1.0
                    }
                }

                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
            }
        }
    }
}