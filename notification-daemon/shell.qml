import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    PanelWindow {
        id: panel
        anchors: {
            left: true
            right: true
            top: true
        }
        implicitHeight: 10
        color: "green"
        visible: true

    }
}