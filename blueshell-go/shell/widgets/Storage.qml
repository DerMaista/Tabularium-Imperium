import qs.services

Chip {
    id: root

    Ref {
        service: MetricsService
        module: "disk"
    }

    ChipText {
        accent: true
        text: "SDD"
    }

    ChipText {
        text: MetricsService.diskPercent
    }
}
