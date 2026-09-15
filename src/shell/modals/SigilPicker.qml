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
    WlrLayershell.namespace: "blueshell-sigil-picker"
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
                onClicked: SigilService.closePicker()
            }
        }

        Rectangle {
            id: panel

            anchors.centerIn: parent

            readonly property real maxWidth: Math.min(keyScope.width * 0.6, 760)
            readonly property real cardWidth: Math.floor((panel.maxWidth - root.uniformMargin * 5) / 4)
            readonly property int columns: {
                const count = SigilService.sigils.length;
                if (count === 0)
                    return 4;
                const rows = Math.ceil(count / 4);
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
                            if (SigilService.applying)
                                return "APPLYING…";
                            if (SigilService.loading)
                                return "LOADING…";
                            if (SigilService.error.length > 0)
                                return "ERROR";
                            return "";
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: SigilService.error.length > 0
                    text: SigilService.error
                    color: Colors.primary
                    font.pixelSize: Config.fontsize
                    font.family: Config.fontfamily
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    visible: !SigilService.loading && SigilService.sigils.length === 0 && SigilService.error.length === 0
                    text: "NO SVGS — DROP ONE IN " + SigilService.userDir
                    color: Colors.primary
                    opacity: 0.6
                    font.pixelSize: Config.fontsize
                    font.family: Config.fontfamily
                    wrapMode: Text.Wrap
                }

                Flow {
                    width: parent.width
                    spacing: root.uniformMargin

                    Repeater {
                        model: SigilService.sigils

                        delegate: Rectangle {
                            id: card

                            required property int index
                            required property var modelData

                            readonly property bool isSelected: card.index === SigilService.selectedIndex
                            readonly property bool isCurrent: card.modelData.name === SigilService.current

                            width: panel.cardWidth
                            height: cardBody.implicitHeight + root.uniformMargin

                            color: Colors.background
                            border {
                                width: card.isSelected ? root.strokeWidth * 2 : root.strokeWidth
                                color: card.isSelected ? Colors.primary : Colors.accent
                            }

                            opacity: SigilService.applying ? 0.5 : 1.0

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

                                Item {
                                    width: parent.width
                                    height: width

                                    Image {
                                        id: preview

                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize.width: parent.width
                                        sourceSize.height: parent.height
                                        source: "file://" + card.modelData.path
                                        visible: false
                                        asynchronous: true
                                    }

                                    ShaderEffect {
                                        x: (preview.width - preview.paintedWidth) / 2
                                        y: (preview.height - preview.paintedHeight) / 2
                                        width: preview.paintedWidth
                                        height: preview.paintedHeight

                                        visible: preview.status === Image.Ready

                                        property variant src: preview
                                        property color primaryColor: Colors.primary
                                        property color accentColor: Colors.accent

                                        fragmentShader: Qt.resolvedUrl("../shaders/color_swap.frag.qsb")
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: (card.isCurrent ? "▸ " : "") + card.modelData.name.toUpperCase()
                                    color: card.isCurrent ? Colors.primary : Colors.accent
                                    font.pixelSize: Config.fontsize * 0.8
                                    font.family: Config.fontfamily
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true

                                onEntered: SigilService.selectedIndex = card.index
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
            SigilService.closePicker();
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_Tab:
            SigilService.moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            SigilService.moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            SigilService.activateSelected();
            event.accepted = true;
            break;
        }
    }

    function activate(index) {
        const sigil = SigilService.sigils[index];
        if (sigil)
            SigilService.apply(sigil.name);
    }
}
