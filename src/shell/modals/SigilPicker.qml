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
                const count = SigilService.entries.length;
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

                // Tabs: shows the half matching the current mode; click or Tab to switch.
                Item {
                    id: header

                    width: parent.width
                    height: tabs.implicitHeight

                    Row {
                        id: tabs

                        spacing: root.uniformMargin

                        Repeater {
                            model: [
                                {
                                    "view": "image",
                                    "label": "WALLPAPERS" + (WallpaperService.theme.length > 0 ? " · " + WallpaperService.theme.toUpperCase() : "")
                                },
                                {
                                    "view": "sigil",
                                    "label": "SIGILS"
                                }
                            ]

                            delegate: Text {
                                id: tab

                                required property var modelData

                                readonly property bool active: SigilService.view === tab.modelData.view

                                text: (tab.active ? "▸ " : "") + tab.modelData.label
                                color: tab.active ? Colors.primary : Colors.accent
                                opacity: tab.active ? 1.0 : 0.6
                                font.pixelSize: Config.fontsize * 0.9
                                font.family: Config.fontfamily

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (!tab.active)
                                            SigilService.switchView();
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        id: title

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.accent
                        opacity: 0.6
                        font.pixelSize: Config.fontsize * 0.9
                        font.family: Config.fontfamily
                        text: {
                            if (SigilService.applying)
                                return "APPLYING…";
                            if (SigilService.loading || WallpaperService.loading)
                                return "LOADING…";
                            if (SigilService.error.length > 0)
                                return "ERROR";
                            return "TAB ⇄";
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
                    visible: SigilService.view === "image" && !WallpaperService.loading && WallpaperService.wallpapers.length === 0
                    text: "NONE — ADD \"wallpapers\" TO THE THEME FILE OR DROP IMAGES IN " + WallpaperService.dir
                    color: Colors.primary
                    opacity: 0.6
                    font.pixelSize: Config.fontsize * 0.8
                    font.family: Config.fontfamily
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    visible: SigilService.view === "sigil" && !SigilService.loading && SigilService.sigils.length === 0 && SigilService.error.length === 0
                    text: "NO SVGS — DROP ONE IN " + SigilService.userDir
                    color: Colors.primary
                    opacity: 0.6
                    font.pixelSize: Config.fontsize
                    font.family: Config.fontfamily
                    wrapMode: Text.Wrap
                }

                // Scrolls once the cards are taller than the screen allows.
                Flickable {
                    id: flick

                    width: parent.width
                    height: Math.min(cards.implicitHeight, Math.max(root.uniformMargin * 4, keyScope.height * 0.85 - header.height - root.uniformMargin * 4))
                    contentWidth: width
                    contentHeight: cards.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: SigilService.entries.length > 0

                    Behavior on contentY {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    Flow {
                        id: cards

                        width: flick.width
                        spacing: root.uniformMargin

                        Repeater {
                            model: SigilService.view === "image" ? WallpaperService.wallpapers : []

                            delegate: PickerCard {
                                id: wallpaperCard

                                required property int index
                                required property var modelData

                                entryIndex: wallpaperCard.index
                                width: panel.cardWidth
                                margin: root.uniformMargin
                                stroke: root.strokeWidth
                                label: wallpaperCard.modelData.name.toUpperCase() + (wallpaperCard.modelData.default ? " · DEFAULT" : "")

                                onIsSelectedChanged: {
                                    if (wallpaperCard.isSelected)
                                        root.ensureVisible(wallpaperCard);
                                }

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: parent.width * 2
                                    sourceSize.height: parent.height * 2
                                    // Cached small thumbnail from the backend; the full image only until it exists.
                                    source: "file://" + (wallpaperCard.modelData.thumb || wallpaperCard.modelData.path)
                                    asynchronous: true
                                    clip: true
                                }
                            }
                        }

                        Repeater {
                            model: SigilService.view === "sigil" ? SigilService.sigils : []

                            delegate: PickerCard {
                                id: sigilCard

                                required property int index
                                required property var modelData

                                entryIndex: sigilCard.index
                                width: panel.cardWidth
                                margin: root.uniformMargin
                                stroke: root.strokeWidth
                                label: sigilCard.modelData.name.toUpperCase()
                                square: true

                                onIsSelectedChanged: {
                                    if (sigilCard.isSelected)
                                        root.ensureVisible(sigilCard);
                                }

                                Image {
                                    id: preview

                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: parent.width
                                    sourceSize.height: parent.height
                                    source: "file://" + sigilCard.modelData.path
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
                                    property color accentColor: Colors.secondary

                                    fragmentShader: Qt.resolvedUrl("../shaders/color_swap.frag.qsb")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Scrolls the card area so the keyboard selection stays in view.
    function ensureVisible(item) {
        const top = item.mapToItem(cards, 0, 0).y;
        const bottom = top + item.height;
        if (top < flick.contentY)
            flick.contentY = top;
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height;
    }

    // A selectable card: the preview goes in as children, the label below it.
    component PickerCard: Rectangle {
        id: card

        required property int entryIndex
        // Inline components do not see the file's ids, so sizes come in here.
        required property real margin
        required property real stroke
        property string label: ""
        property bool square: false
        default property alias preview: previewArea.data

        readonly property bool isSelected: card.entryIndex === SigilService.selectedIndex
        readonly property bool isCurrent: SigilService.isCurrentEntry(SigilService.entries[card.entryIndex])

        height: cardBody.implicitHeight + card.margin

        color: Colors.background
        border {
            width: card.isSelected ? card.stroke * 2 : card.stroke
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
                margins: card.margin / 2
            }
            spacing: card.margin / 3

            Item {
                id: previewArea

                width: parent.width
                height: card.square ? width : Math.round(width * 9 / 16)
                clip: true
            }

            Text {
                width: parent.width
                text: (card.isCurrent ? "▸ " : "") + card.label
                color: card.isCurrent ? Colors.primary : Colors.accent
                font.pixelSize: Config.fontsize * 0.8
                font.family: Config.fontfamily
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: SigilService.selectedIndex = card.entryIndex
            onClicked: SigilService.activate(card.entryIndex)
        }
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            SigilService.closePicker();
            event.accepted = true;
            break;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            SigilService.switchView();
            event.accepted = true;
            break;
        case Qt.Key_Right:
            SigilService.moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Left:
            SigilService.moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Down:
            SigilService.moveSelection(panel.columns);
            event.accepted = true;
            break;
        case Qt.Key_Up:
            SigilService.moveSelection(-panel.columns);
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
}
