import QtQuick

Item {
    id: controller

    property var popup: null
    property bool iconHovered: false
    property int closeDelay: 180

    function handleToggle(visible) {
        if (!popup) {
            return
        }

        if (visible) {
            closeTimer.stop()
            popup.visible = true
        } else if (!popup.isHovered) {
            closeTimer.restart()
        }
    }

    function handlePopupHoverChanged() {
        if (!popup) {
            return
        }

        if (popup.isHovered) {
            closeTimer.stop()
        } else if (!iconHovered) {
            closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: controller.closeDelay
        repeat: false
        onTriggered: {
            if (controller.popup && !controller.iconHovered && !controller.popup.isHovered) {
                controller.popup.visible = false
            }
        }
    }
}