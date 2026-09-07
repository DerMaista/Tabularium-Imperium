import qs.services

Chip {
    id: root

    visible: NetworkService.available
    implicitWidth: NetworkService.available ? root.contentWidth : 0
    implicitHeight: NetworkService.available ? root.contentHeight : 0

    ChipText {
        accent: true
        text: "NET"
    }

    ChipText {
        text: NetworkService.label
    }

    ChipText {
        accent: true
        visible: NetworkService.connected && NetworkService.type === "wifi"
        text: NetworkService.strength + "%"
    }
}
