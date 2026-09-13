pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services

PanelWindow {
    id: root

    readonly property real screenSize: root.screen ? Math.min(root.screen.width, root.screen.height) : 1000
    readonly property real uniformMargin: Math.max(root.screenSize * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blueshell-theme-picker"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => root.handleKey(event)

        Rectangle {
            anchors.fill: parent
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: ThemeService.closePicker()
            }
        }

        Rectangle {
            id: panel

            anchors.centerIn: parent

            readonly property real maxWidth: Math.min(keyScope.width * 0.6, 760)
            readonly property real cardWidth: Math.floor((panel.maxWidth - root.uniformMargin * 4) / 3)
            readonly property int columns: {
                const count = ThemeService.themes.length;
                if (count === 0)
                    return 3;
                const rows = Math.ceil(count / 3);
                return Math.ceil(count / rows);
            }

            width: Math.min(panel.maxWidth, Math.ceil(panel.columns * panel.cardWidth + (panel.columns + 1) * root.uniformMargin))
            implicitHeight: layout.implicitHeight + root.uniformMargin * 2

            color: Colors.background
            border {
                width: root.strokeWidth
                color: Colors.accent
            }

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: layout

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: root.uniformMargin
                }
                spacing: root.uniformMargin

                Item {
                    width: parent.width
                    height: title.implicitHeight
                    visible: title.text !== ""

                    Text {
                        id: title

                        anchors.right: parent.right
                        color: Colors.accent
                        opacity: 0.6
                        font.pixelSize: Config.fontsize
                        font.family: Config.fontfamily
                        text: {
                            if (ThemeService.applying)
                                return "APPLYING…";
                            if (ThemeService.loading)
                                return "LOADING…";
                            if (ThemeService.error.length > 0)
                                return "ERROR";
                            return "";
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: ThemeService.error.length > 0
                    text: ThemeService.error
                    color: Colors.primary
                    font.pixelSize: Config.fontsize
                    font.family: Config.fontfamily
                    wrapMode: Text.Wrap
                }

                Text {
                    visible: !ThemeService.loading && ThemeService.themes.length === 0 && ThemeService.error.length === 0
                    text: "NO THEMES IN themesDir"
                    color: Colors.primary
                    opacity: 0.6
                    font.pixelSize: Config.fontsize
                    font.family: Config.fontfamily
                }

                Flow {
                    width: parent.width
                    spacing: root.uniformMargin

                    Repeater {
                        model: ThemeService.themes

                        delegate: Rectangle {
                            id: card

                            required property int index
                            required property var modelData

                            readonly property bool isSelected: card.index === ThemeService.selectedIndex
                            readonly property bool isCurrent: card.modelData.name === ThemeService.current

                            readonly property color themeBackground: card.modelData.background || Colors.background
                            readonly property color themePrimary: card.modelData.primary || Colors.primary
                            readonly property color themeAccent: card.modelData.accent || Colors.accent

                            width: panel.cardWidth
                            height: cardBody.implicitHeight + root.uniformMargin

                            color: card.themeBackground
                            border {
                                width: card.isSelected ? root.strokeWidth * 2 : root.strokeWidth
                                color: card.isSelected ? card.themePrimary : card.themeAccent
                            }

                            opacity: ThemeService.applying ? 0.5 : 1.0

                            Behavior on border.width {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            Column {
                                id: cardBody

                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: root.uniformMargin / 2
                                }
                                spacing: root.uniformMargin / 3

                                Text {
                                    width: parent.width
                                    text: (card.isCurrent ? "▸ " : "") + card.modelData.name.toUpperCase()
                                    color: card.themePrimary
                                    font.pixelSize: Config.fontsize
                                    font.family: Config.fontfamily
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: root.uniformMargin / 4

                                    Repeater {
                                        model: [card.themeBackground, card.themePrimary, card.themeAccent]

                                        delegate: Rectangle {
                                            required property var modelData

                                            width: (cardBody.width - root.uniformMargin / 2) / 3
                                            height: Config.fontsize
                                            color: modelData
                                            border {
                                                width: 1
                                                color: card.themeAccent
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: card.modelData.mode.toUpperCase()
                                    color: card.themeAccent
                                    font.pixelSize: Config.fontsize * 0.8
                                    font.family: Config.fontfamily
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true

                                onEntered: ThemeService.selectedIndex = card.index
                                onClicked: root.activate(card.index)
                            }
                        }
                    }
                }
            }
        }
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            ThemeService.closePicker();
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_Tab:
            ThemeService.moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            ThemeService.moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            ThemeService.activateSelected();
            event.accepted = true;
            break;
        }
    }

    function activate(index) {
        const theme = ThemeService.themes[index];
        if (theme)
            ThemeService.apply(theme.name);
    }

}
