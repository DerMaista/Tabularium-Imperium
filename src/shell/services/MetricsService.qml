pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: BackendService.has("metrics")

    property int refCount: 0

    property var moduleRefs: ({})

    function addModule(name) {
        const refs = root.moduleRefs;
        refs[name] = (refs[name] || 0) + 1;
        root.moduleRefs = refs;
        root.recomputeModules();
    }

    function removeModule(name) {
        const refs = root.moduleRefs;
        if (!refs[name])
            return;
        refs[name]--;
        if (refs[name] <= 0)
            delete refs[name];
        root.moduleRefs = refs;
        root.recomputeModules();
    }

    property string enabledModulesKey: "[]"

    function recomputeModules() {
        const names = Object.keys(root.moduleRefs).sort();
        root.enabledModulesKey = JSON.stringify(names);
    }

    readonly property var enabledModules: JSON.parse(root.enabledModulesKey)

    property bool desktopVisible: true

    readonly property int updateInterval: {
        if (root.refCount === 0)
            return 60000;
        return root.desktopVisible ? 3000 : 15000;
    }

    property real cpuPercent: -1
    property real memPercent: -1
    property int memUsedMB: 0
    property int memTotalMB: 0
    property string diskPercent: "--"
    property real diskUsedGB: 0
    property real diskTotalGB: 0
    property string uptimeText: "--"

    signal updated

    function applyMetrics(data) {
        if (!data)
            return;

        if (data.cpu && data.cpu.percent !== undefined)
            root.cpuPercent = data.cpu.percent;

        if (data.memory) {
            root.memPercent = data.memory.percent;
            root.memUsedMB = data.memory.usedMB;
            root.memTotalMB = data.memory.totalMB;
        }

        if (data.disk) {
            root.diskPercent = data.disk.formatted;
            root.diskUsedGB = data.disk.usedGB;
            root.diskTotalGB = data.disk.totalGB;
        }

        if (data.uptime)
            root.uptimeText = data.uptime.formatted;

        root.updated();
    }

    function scheduleConfigure() {
        Qt.callLater(root.configure);
    }

    function configure() {
        if (!BackendService.connected)
            return;

        BackendService.sendRequest("metrics.configure", {
            "modules": root.enabledModules,
            "intervalMs": root.updateInterval
        });
    }

    onEnabledModulesKeyChanged: root.scheduleConfigure()
    onUpdateIntervalChanged: root.scheduleConfigure()

    Connections {
        target: BackendService

        function onMetricsEvent(data) {
            root.applyMetrics(data);
        }

        function onLinkUp() {
            root.configure();
        }

        function onLinkDown() {
            root.cpuPercent = -1;
            root.memPercent = -1;
            root.diskPercent = "--";
            root.uptimeText = "--";
        }
    }
}
