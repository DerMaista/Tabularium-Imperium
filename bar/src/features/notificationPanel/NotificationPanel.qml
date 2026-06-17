import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.src.globals.states
import "."

Scope {
    id: notifPanel

    property int popupWidth: 380
    property int popupSpacing: 12
    property int popupTopMargin: 25
    property int popupRightMargin: 25
    property int popupStackHeight: 150
    property int popupTimeoutMs: 6000
    property var popupEntries: []

    function toggle() {
        if (NotificationManager.trackedList.length > 0) {
            hide()
        }
    }

    function show() {}

    function hide() {
        const notifications = [...NotificationManager.trackedList]
        for (let i = 0; i < notifications.length; i++) {
            const notification = notifications[i]
            if (notification) {
                notification.tracked = false
                NotificationManager.removeNotification(notification)
            }
        }
    }

    function closeNotification(notification) {
        if (!notification)
            return

        notification.tracked = false
        NotificationManager.removeNotification(notification)
    }

    function relayoutPopups() {
        for (let i = 0; i < popupEntries.length; i++) {
            const entry = popupEntries[i]
            if (entry && entry.window)
                entry.window.stackIndex = i
        }
    }

    function findPopupIndex(notification) {
        for (let i = 0; i < popupEntries.length; i++) {
            const entry = popupEntries[i]
            if (entry && entry.notification === notification)
                return i
        }
        return -1
    }

    function createPopup(notification) {
        if (!notification)
            return
        if (findPopupIndex(notification) !== -1)
            return

        const window = popupComponent.createObject(notifPanel, {
            notification: notification,
            createdAt: Date.now(),
            stackIndex: popupEntries.length
        })

        if (!window)
            return

        popupEntries = [...popupEntries, { notification: notification, window: window }]
    }

    function removePopup(notification) {
        const index = findPopupIndex(notification)
        if (index === -1)
            return

        const entry = popupEntries[index]
        if (entry && entry.window)
            entry.window.destroy()

        const nextEntries = [...popupEntries]
        nextEntries.splice(index, 1)
        popupEntries = nextEntries
        relayoutPopups()
    }

    Component {
        id: popupComponent

        PanelWindow {
            id: popup
            property var notification: null
            property double createdAt: Date.now()
            property int stackIndex: 0

            anchors {
                top: true
                right: true
            }

            margins {
                top: notifPanel.popupTopMargin + stackIndex * (notifPanel.popupStackHeight + notifPanel.popupSpacing)
                right: notifPanel.popupRightMargin
            }

            color: "transparent"
            implicitWidth: notifPanel.popupWidth
            implicitHeight: panelRect.implicitHeight
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: panelRect
                color: Colors.surface_variant
                radius: ThemeManager.radiusLarge
                opacity: 0.95
                implicitWidth: notifPanel.popupWidth
                implicitHeight: notifBody.implicitHeight + ThemeManager.spacingMedium * 2

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true

                    onContainsMouseChanged: {
                        if (!cooldownAnim.running)
                            return

                        if (containsMouse)
                            cooldownAnim.pause()
                        else
                            cooldownAnim.resume()
                    }
                }

                NotificationItem {
                    id: notifBody
                    notification: popup.notification
                    anchors {
                        left: parent.left
                        right: closeButton.left
                        leftMargin: ThemeManager.spacingMedium
                        rightMargin: ThemeManager.spacingSmall
                        top: parent.top
                        topMargin: ThemeManager.spacingMedium
                    }

                    onClosed: notifPanel.closeNotification(popup.notification)
                }

                Rectangle {
                    id: closeButton
                    anchors {
                        right: parent.right
                        top: parent.top
                        rightMargin: ThemeManager.spacingSmall
                        topMargin: ThemeManager.spacingSmall
                    }
                    width: 24
                    height: 24
                    radius: ThemeManager.radiusSmall
                    color: Colors.surface_container_high

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Colors.on_surface
                        font.family: ThemeManager.fontFamily
                        font.pixelSize: ThemeManager.fontSizeSmall
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notifPanel.closeNotification(popup.notification)
                    }
                }

                Rectangle {
                    id: cooldownBar
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                    }
                    height: 4
                    width: 0
                    radius: 2
                    color: Colors.primary

                    PropertyAnimation {
                        id: cooldownAnim
                        target: cooldownBar
                        property: "width"
                        from: panelRect.width
                        to: 0
                        duration: notifPanel.popupTimeoutMs
                        onFinished: notifPanel.closeNotification(popup.notification)
                    }
                }

                Component.onCompleted: {
                    const elapsed = Date.now() - popup.createdAt
                    const remaining = Math.max(0, notifPanel.popupTimeoutMs - elapsed)

                    if (remaining <= 0) {
                        notifPanel.closeNotification(popup.notification)
                        return
                    }

                    cooldownBar.width = panelRect.width * (remaining / notifPanel.popupTimeoutMs)
                    cooldownAnim.from = cooldownBar.width
                    cooldownAnim.duration = remaining
                    cooldownAnim.start()
                }
            }
        }
    }

    IpcHandler {
        target: "notification"
        function toggle() { notifPanel.toggle() }
        function show() { notifPanel.show() }
        function hide() { notifPanel.hide() }
    }

    Connections {
        target: NotificationManager
        function onNotificationReceived(notification) {
            notifPanel.createPopup(notification)
        }

        function onTrackedListChanged() {
            const current = NotificationManager.trackedList

            for (let i = popupEntries.length - 1; i >= 0; i--) {
                const entry = popupEntries[i]
                if (entry && current.indexOf(entry.notification) === -1)
                    notifPanel.removePopup(entry.notification)
            }

            for (let i = 0; i < current.length; i++) {
                const notification = current[i]
                if (notifPanel.findPopupIndex(notification) === -1)
                    notifPanel.createPopup(notification)
            }

            notifPanel.relayoutPopups()
        }
    }
}