import Quickshell
import Quickshell.Services.Notifications
pragma Singleton

Singleton {
    id: notificationManager
    readonly property alias list: server.trackedNotifications
    signal notificationReceived(var notification)
    
    property int maxNotifications: 100
    property bool doNotDisturb: false
    property var trackedList: []

    function listCount() {
        return trackedList.length
    }

    function listAt(index) {
        return trackedList[index] || null
    }

    NotificationServer {
        id: server
        onNotification: notif => {
            if (!doNotDisturb) {
                notif.tracked = true
                notificationReceived(notif)

                notificationManager.trackedList = [notif, ...notificationManager.trackedList]
                console.log(`[notification] added to trackedList, now has ${notificationManager.trackedList.length} items`)
                
                const count = listCount()
                if (count > maxNotifications) {
                    const oldest = trackedList[trackedList.length - 1]
                    if (oldest) {
                        oldest.tracked = false
                        removeNotification(oldest)
                    }
                }
            }
        }
    }
    
    function removeNotification(notif) {
        notificationManager.trackedList = notificationManager.trackedList.filter(n => n !== notif)
        console.log(`[notification] removed from trackedList, now has ${notificationManager.trackedList.length} items`)
    }
    
    function toggleDoNotDisturb() {
        doNotDisturb = !doNotDisturb
    }
}