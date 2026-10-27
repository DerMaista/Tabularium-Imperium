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
    Ref {
        service: MetricsService
        module: "gpu"
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

    ChipText {
        accent: true
        text: "• GPU"
    }

    ChipText {
        text: MetricsService.gpuPercent < 0 ? "--" : Math.round(MetricsService.gpuPercent) + "%"
    }

    // Integrated GPUs share system RAM and have no VRAM of their own.
    ChipText {
        visible: MetricsService.vramPercent >= 0
        accent: true
        text: "• VRAM"
    }

    ChipText {
        visible: MetricsService.vramPercent >= 0
        text: Math.round(MetricsService.vramPercent) + "%"
    }
}
