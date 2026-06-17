import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.src.components.panels
import qs.src.globals.states

PopupWindow {
    id: quotePopup
    visible: false
    implicitWidth: 700
    implicitHeight: 180
    color: "transparent"
    property bool isHovered: popupHoverHandler.hovered
    property QtObject bar: null

    anchor.window: bar
    anchor.rect.x: bar ? bar.width : 0
    anchor.rect.y: bar ? bar.height : 0
    property string currentQuote: "No quotes"

    onVisibleChanged: if (visible) loadRandomQuote()

    HoverHandler {
        id: popupHoverHandler
    }

    function loadRandomQuote() {
        quoteProc.running = true
    }

    Process {
        id: quoteProc
        command: ["hydractl", "quote"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var quote = this.text.trim()

                if (quote && quote.length > 0) {
                    quote = quote.slice(0, -1)   // remove last character
                    quotePopup.currentQuote = quote
                } else {
                    quotePopup.currentQuote = "No quotes available"
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 12
        spacing: 12

        Text {
            text: "Quote"
            font.pixelSize: 18
            font.bold: true
            color: Colors.on_surface
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: Colors.surface_variant
            border.color: Colors.outline
            border.width: 1

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                Text {
                    id: quoteText
                    text: quotePopup.currentQuote
                    color: Colors.on_surface_variant
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                    font.family: "Maple Mono NF"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 30
                radius: 8
                color: newQuoteMouseArea.containsMouse ? Colors.primary : Colors.surface_variant
                border.color: Colors.outline
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "New Quote"
                    font.family: "Maple Mono NF"
                    font.pixelSize: 11
                    color: newQuoteMouseArea.containsMouse ? Colors.on_primary : Colors.on_surface_variant
                }

                MouseArea {
                    id: newQuoteMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: quotePopup.loadRandomQuote()
                }
            }
        }
    }

    Component.onCompleted: loadRandomQuote()
}