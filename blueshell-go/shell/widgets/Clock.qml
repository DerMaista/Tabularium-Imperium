import qs.services

Chip {
    id: root

    ChipText {
        text: ClockService.time
    }

    ChipText {
        text: ClockService.date
    }
}
