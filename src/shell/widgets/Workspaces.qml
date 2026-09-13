pragma ComponentBehavior: Bound

import QtQuick

import qs.config
import qs.services

Chip {
    id: root

    spacing: 10

    readonly property string monitorName: root.screen.name

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
        return map[n] ?? String(n);
    }

    function refresh() {
        const tags = WorkspaceService.tagsFor(root.monitorName);

        while (wsModel.count > tags.length)
            wsModel.remove(wsModel.count - 1);

        for (let i = 0; i < tags.length; i++) {
            const tag = tags[i];
            if (i >= wsModel.count) {
                wsModel.append({
                    "tagIndex": tag.index,
                    "isActive": tag.active,
                    "clients": tag.clients
                });
                continue;
            }

            const row = wsModel.get(i);
            if (row.tagIndex !== tag.index)
                wsModel.setProperty(i, "tagIndex", tag.index);
            if (row.isActive !== tag.active)
                wsModel.setProperty(i, "isActive", tag.active);
            if (row.clients !== tag.clients)
                wsModel.setProperty(i, "clients", tag.clients);
        }
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: WorkspaceService

        function onMonitorUpdated(name) {
            if (name === root.monitorName)
                root.refresh();
        }
    }

    ListModel {
        id: wsModel
    }

    Row {
        spacing: 10

        Repeater {
            model: wsModel

            delegate: Text {
                id: tagText

                required property int tagIndex
                required property bool isActive
                required property int clients

                text: root.toRomanDigit(tagText.tagIndex)
                anchors.verticalCenter: parent.verticalCenter

                font.pixelSize: Config.fontsize
                font.family: Config.fontfamily

                opacity: tagText.isActive || tagText.clients >= 1 ? 1.0 : 0.4
                color: tagText.isActive ? Colors.primary : Colors.accent

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
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        if (!tagText.isActive)
                            WorkspaceService.view(tagText.tagIndex);
                    }
                    onEntered: tagText.scale = 1.2
                    onExited: tagText.scale = 1.0
                }
            }
        }
    }
}
