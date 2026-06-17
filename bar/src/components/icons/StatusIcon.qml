import QtQuick

import qs.src.globals.states
import qs.src.globals.config

AnimatedIcon {
    id: statusIcon
    
    property var statusUpdateFunction: null
    property int updateInterval: 2000
    property bool autoUpdate: true
    
    Timer {
        interval: statusIcon.updateInterval
        running: statusIcon.autoUpdate
        repeat: true
        onTriggered: {
            if (statusIcon.statusUpdateFunction) {
                statusIcon.statusUpdateFunction()
            }
        }
    }
    
    Component.onCompleted: {
        if (statusIcon.statusUpdateFunction) {
            statusIcon.statusUpdateFunction()
        }
    }
}