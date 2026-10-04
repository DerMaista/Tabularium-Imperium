pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.config
import qs.services

Column {
    id: root

    required property QsMenuEntry entry

    required property real uniformMargin
    required property real strokeWidth

    property int depth: 0

    property bool expanded: false

    property bool submenuOpen: false

    readonly property real indent: root.depth * root.uniformMargin

    readonly property bool interactive: root.entry.enabled && !root.entry.isSeparator

    readonly property string mark: {
        if (root.entry.buttonType === QsMenuButtonType.CheckBox)
            return root.entry.checkState === Qt.Checked ? "[X]" : "[ ]";
        if (root.entry.buttonType === QsMenuButtonType.RadioButton)
            return root.entry.checkState === Qt.Checked ? "(*)" : "( )";
        return "";
    }

    spacing: 0

    Item {
        width: root.width
        height: root.uniformMargin / 2

        visible: root.entry.isSeparator

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: root.uniformMargin / 2 + root.indent
                rightMargin: root.uniformMargin / 2
            }

            height: Math.max(1, root.strokeWidth / 2)
            color: Colors.accent
            opacity: 0.4
        }
    }

    Rectangle {
        id: row

        width: root.width
        height: line.implicitHeight + root.uniformMargin / 2

        visible: !root.entry.isSeparator
        opacity: root.entry.enabled ? 1 : 0.4

        readonly property bool active: area.containsMouse && root.interactive

        color: row.active ? Colors.accent : "transparent"

        RowLayout {
            id: line

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: root.uniformMargin / 2 + root.indent
                rightMargin: root.uniformMargin / 2
            }
            spacing: root.uniformMargin / 3

            Text {
                visible: root.mark !== ""
                text: root.mark
                color: row.active ? Colors.background : Colors.accent
                font.pixelSize: Config.fontsize
                font.family: Config.fontfamily
            }

            TrayIcon {
                Layout.alignment: Qt.AlignVCenter

                visible: root.entry.icon !== ""
                size: Config.fontsize
                source: root.entry.icon
                tint: row.active ? Colors.background : Colors.primary
            }

            Text {
                Layout.fillWidth: true

                text: root.entry.text.toUpperCase()
                color: row.active ? Colors.background : Colors.primary
                font.pixelSize: Config.fontsize
                font.family: Config.fontfamily
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                visible: root.entry.hasChildren
                text: root.expanded ? "▾" : "▸"
                color: row.active ? Colors.background : Colors.accent
                font.pixelSize: Config.fontsize
                font.family: Config.fontfamily
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            enabled: root.interactive
            hoverEnabled: true

            onClicked: {
                if (root.entry.hasChildren) {
                    root.expanded = !root.expanded;
                    return;
                }

                root.entry.triggered();
                TrayService.closeMenu();
            }
        }
    }

    onExpandedChanged: {
        if (root.expanded) {
            settle.stop();
            root.submenuOpen = true;
            return;
        }

        settle.restart();
    }

    Timer {
        id: settle

        interval: 400

        onTriggered: root.submenuOpen = root.expanded
    }

    Loader {
        id: submenu

        width: root.width

        height: root.expanded ? submenu.implicitHeight : 0

        visible: root.expanded
        active: root.entry.hasChildren && root.submenuOpen
        source: Qt.resolvedUrl("TrayMenuBranch.qml")

        onLoaded: {
            submenu.item.menu = root.entry;
            submenu.item.uniformMargin = root.uniformMargin;
            submenu.item.strokeWidth = root.strokeWidth;
            submenu.item.depth = root.depth + 1;
        }
    }
}
