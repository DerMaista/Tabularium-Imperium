import qs.services

Chip {
    id: root

    readonly property bool shown: NetworkService.connected && NetworkService.address !== ""

    visible: root.shown
    implicitWidth: root.shown ? root.contentWidth : 0
    implicitHeight: root.shown ? root.contentHeight : 0

    ChipText {
        accent: true
        text: "IP"
    }

    ChipText {
        text: NetworkService.address
    }
}
