import qs.services

Chip {
    id: root

    Ref {
        service: MetricsService
        module: "uptime"
    }

    ChipText {
        accent: true
        text: "UP"
    }

    ChipText {
        text: MetricsService.uptimeText
    }
}
