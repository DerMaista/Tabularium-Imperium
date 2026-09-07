pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property string time: "--:--"
    property string date: ""
    property double epochMs: 0

    function applyClock(data) {
        if (!data)
            return;
        root.time = data.time;
        root.date = data.date;
        root.epochMs = data.epochMs;
    }

    Connections {
        target: BackendService

        function onClockEvent(data) {
            root.applyClock(data);
        }
    }
}
