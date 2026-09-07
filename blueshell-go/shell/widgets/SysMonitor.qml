import qs.services

Chip {
    id: root

    spacing: 12

    Ref {
        service: MetricsService
        module: "cpu"
    }
    Ref {
        service: MetricsService
        module: "memory"
    }

    ChipText {
        accent: true
        text: "CPU"
    }

    ChipText {
        text: MetricsService.cpuPercent < 0 ? "--" : Math.round(MetricsService.cpuPercent) + "%"
    }

    ChipText {
        accent: true
        text: "• RAM"
    }

    ChipText {
        text: MetricsService.memPercent < 0 ? "--" : Math.round(MetricsService.memPercent) + "%"
    }
}
