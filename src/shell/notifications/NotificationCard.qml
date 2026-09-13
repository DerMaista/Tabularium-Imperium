pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

import qs.config
import qs.services

// One card, drawn the same way whether it is a toast in the corner or a row in
// the centre. The two differ only in which of the flags below are set.
Rectangle {
    id: root

    required property Notification notification

    required property real uniformMargin
    required property real strokeWidth

    property bool showTime: false
    property bool showClose: false
    property bool clickable: false

    signal closeRequested
    signal clicked

    readonly property bool critical: root.notification.urgency === NotificationUrgency.Critical

    // The palette is three colours, so urgency cannot be a fourth. It is drawn
    // the way the rest of the shell draws emphasis instead: a doubled stroke,
    // and the accent used as a fill rather than as a line.
    readonly property real borderWidth: root.critical ? root.strokeWidth * 2 : root.strokeWidth

    readonly property string iconSource: {
        if (root.notification.image !== "")
            return root.notification.image;
        // `check` makes a missing icon return "" rather than a path to nothing.
        if (root.notification.appIcon !== "")
            return Quickshell.iconPath(root.notification.appIcon, true);
        return "";
    }

    implicitHeight: layout.implicitHeight + root.uniformMargin

    color: Colors.background
    border {
        width: root.borderWidth
        color: Colors.accent
    }

    // Declared before the content on purpose: the action buttons and the close
    // glyph sit above it, so they take their own clicks and only the rest of
    // the card falls through to here.
    MouseArea {
        anchors.fill: parent
        enabled: root.clickable

        onClicked: root.clicked()
    }

    RowLayout {
        id: layout

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.uniformMargin / 2
        }
        spacing: root.uniformMargin / 2

        Image {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Config.fontsize * 2
            Layout.preferredHeight: Config.fontsize * 2

            visible: root.iconSource !== ""
            fillMode: Image.PreserveAspectFit
            // Decoded at the size it is drawn at, not at whatever the sender
            // happened to attach.
            sourceSize.width: Config.fontsize * 2
            sourceSize.height: Config.fontsize * 2
            source: root.iconSource
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.strokeWidth

            RowLayout {
                Layout.fillWidth: true
                spacing: root.uniformMargin / 3

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter

                    visible: root.critical
                    color: Colors.accent

                    implicitWidth: mark.implicitWidth + root.strokeWidth * 4
                    implicitHeight: mark.implicitHeight + root.strokeWidth * 2

                    Text {
                        id: mark

                        anchors.centerIn: parent
                        text: "!"
                        color: Colors.background
                        font.pixelSize: Config.fontsize - 2
                        font.family: Config.fontfamily
                        font.bold: true
                    }
                }

                Text {
                    Layout.fillWidth: true

                    text: root.notification.summary
                    color: Colors.primary
                    font.pixelSize: Config.fontsize
                    font.family: Config.fontfamily
                    font.bold: true
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter

                    visible: root.showTime && text !== ""
                    text: NotificationService.timeOf(root.notification.id)
                    color: Colors.accent
                    opacity: 0.8
                    font.pixelSize: Config.fontsize - 3
                    font.family: Config.fontfamily
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter

                    visible: root.showClose
                    text: "✕"
                    color: closeArea.containsMouse ? Colors.primary : Colors.accent
                    font.pixelSize: Config.fontsize - 2
                    font.family: Config.fontfamily

                    MouseArea {
                        id: closeArea

                        anchors.fill: parent
                        // A one-character hit box is a poor target; this widens
                        // it without moving the glyph.
                        anchors.margins: -root.strokeWidth * 2
                        hoverEnabled: true

                        onClicked: root.closeRequested()
                    }
                }
            }

            Text {
                Layout.fillWidth: true

                visible: text !== ""
                text: root.notification.body
                color: Colors.primary
                opacity: 0.75
                font.pixelSize: Config.fontsize - 1
                font.family: Config.fontfamily
                // Plain, deliberately: `bodyMarkupSupported` is false, so an app
                // that sends markup anyway gets it shown rather than rendered,
                // and no <img> tag can fetch anything.
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 6
                elide: Text.ElideRight
            }

            Text {
                visible: text !== ""
                text: root.notification.appName.toUpperCase()
                color: Colors.accent
                opacity: 0.7
                font.pixelSize: Config.fontsize - 3
                font.family: Config.fontfamily
            }

            // The original daemon advertised `actionsSupported: true` and then
            // never drew a single action, so an app's buttons silently did
            // nothing. These make that claim true.
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: root.strokeWidth

                visible: root.notification.actions.length > 0
                spacing: root.strokeWidth * 2

                Repeater {
                    model: root.notification.actions

                    delegate: Rectangle {
                        id: button

                        required property NotificationAction modelData

                        implicitWidth: label.implicitWidth + root.uniformMargin / 2
                        implicitHeight: label.implicitHeight + root.strokeWidth * 4

                        color: buttonArea.containsMouse ? Colors.accent : Colors.background
                        border {
                            width: root.strokeWidth
                            color: Colors.accent
                        }

                        Text {
                            id: label

                            anchors.centerIn: parent
                            text: button.modelData.text.toUpperCase()
                            color: buttonArea.containsMouse ? Colors.background : Colors.primary
                            font.pixelSize: Config.fontsize - 3
                            font.family: Config.fontfamily
                        }

                        MouseArea {
                            id: buttonArea

                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: NotificationService.invokeAction(root.notification, button.modelData)
                        }
                    }
                }
            }
        }
    }
}
