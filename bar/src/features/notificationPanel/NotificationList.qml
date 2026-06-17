import QtQuick
import QtQuick.Controls
import qs.src.globals.states

Flickable {
    id: notificationList
    clip: true
    contentHeight: contentColumn.implicitHeight
    
    property alias model: repeater.model
    signal notificationClicked(var notification)
    signal notificationClosed(var notification)

    Column {
        id: contentColumn
        width: parent.width
        spacing: ThemeManager.spacingMedium

        Repeater {
            id: repeater
            model: notificationList.model

            NotificationItem {
                property var delegateNotification: (typeof modelData !== "undefined")
                    ? modelData
                    : ((typeof model !== "undefined") ? model : null)

                notification: delegateNotification
                onClicked: {
                    if (delegateNotification)
                        notificationList.notificationClicked(delegateNotification)
                }
                onClosed: {
                    if (delegateNotification)
                        notificationList.notificationClosed(delegateNotification)
                }
                
                opacity: 1
                scale: 1
            }
        }
        
        // Empty state
        Rectangle {
            visible: repeater.count === 0
            width: parent.width
            height: 100
            color: "transparent"
            
            Column {
                anchors.centerIn: parent
                spacing: ThemeManager.spacingSmall
                
                Text {
                    text: "📋"
                    font.pixelSize: 32
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "No notifications"
                    font.family: ThemeManager.fontFamily
                    font.pixelSize: ThemeManager.fontSizeMedium
                    color: Colors.on_surface_variant
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        width: 6
        background: Rectangle { color: "transparent" }
        contentItem: Rectangle {
            radius: 3
            color: Colors.outline
            opacity: 0.6
        }
    }
}