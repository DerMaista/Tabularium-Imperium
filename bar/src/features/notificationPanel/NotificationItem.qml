import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.src.globals.states
import "."

Rectangle {
    id: notificationItem
    width: parent ? parent.width : 300
    implicitHeight: contentColumn.implicitHeight + 16
    height: implicitHeight
    radius: ThemeManager.radiusMedium
    color: Colors.surface
    border.color: Colors.outline
    border.width: 1
    
    property var notification: null
    
    signal closed()
    signal clicked()

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: ThemeManager.spacingMedium
        spacing: ThemeManager.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: ThemeManager.spacingSmall

            Text {
                text: notificationItem.notification ? (notificationItem.notification.appName || "Unknown App") : "Unknown App"
                font.family: ThemeManager.fontFamily
                font.pixelSize: ThemeManager.fontSizeSmall
                font.weight: Font.Medium
                color: Colors.primary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: formatTime(notificationItem.notification ? notificationItem.notification.timestamp : null)
                font.family: ThemeManager.fontFamily
                font.pixelSize: ThemeManager.fontSizeSmall
                color: Colors.on_surface_variant
                opacity: 0.7
            }
        }

        Text {
            visible: !!(notificationItem.notification && notificationItem.notification.summary)
            text: notificationItem.notification ? (notificationItem.notification.summary || "") : ""
            font.family: ThemeManager.fontFamily
            font.pixelSize: ThemeManager.fontSizeMedium
            font.weight: Font.Medium
            color: Colors.on_surface
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Text {
            visible: !!(notificationItem.notification && notificationItem.notification.body)
            text: notificationItem.notification ? (notificationItem.notification.body || "") : ""
            font.family: ThemeManager.fontFamily
            font.pixelSize: ThemeManager.fontSizeSmall
            color: Colors.on_surface_variant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            visible: !!(notificationItem.notification && notificationItem.notification.actions && notificationItem.notification.actions.length > 0)
            Layout.fillWidth: true
            spacing: ThemeManager.spacingSmall

            Repeater {
                model: notificationItem.notification && notificationItem.notification.actions ? notificationItem.notification.actions : []

                Rectangle {
                    radius: ThemeManager.radiusSmall
                    color: Colors.primary_container
                    height: 24
                    Layout.fillWidth: true

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name || ""
                        font.family: ThemeManager.fontFamily
                        font.pixelSize: ThemeManager.fontSizeSmall
                        color: Colors.on_primary_container
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (notificationItem.notification)
                                notificationItem.notification.invokeAction(modelData.id)
                            notificationItem.clicked()
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: notificationItem.clicked()
        
        onPressAndHold: {
            if (notificationItem.notification) {
                notificationItem.notification.tracked = false
                NotificationManager.removeNotification(notificationItem.notification)
                notificationItem.closed()
            }
        }
    }

    function formatTime(timestamp) {
        if (!timestamp) return ""
        const date = new Date(timestamp)
        const now = new Date()
        const diffMs = now - date
        const diffMins = Math.floor(diffMs / 60000)
        
        if (diffMins < 1) return "Now"
        if (diffMins < 60) return `${diffMins}m ago`
        if (diffMins < 1440) return `${Math.floor(diffMins / 60)}h ago`
        return `${Math.floor(diffMins / 1440)}d ago`
    }
}