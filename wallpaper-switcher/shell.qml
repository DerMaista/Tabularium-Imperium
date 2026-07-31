import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.config

PanelWindow {
    id: root
    visible: true
    color: "transparent"

    implicitWidth: 1000
    implicitHeight: 1000

    focusable: true
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property var wallpapers: []
    property var coords: generateHexDisk(wallpapers.length)
    property bool applying: false

    Process {
        id: scanProcess
        running: false
        command: ["sh", "-c",
            "find " + shellQuote(Config.wallpaperDir) +
            " -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' \\) 2>/dev/null | sort"]

        stdout: StdioCollector {
            id: scanCollector
        }

        onExited: (exitCode) => {
            root.wallpapers = scanCollector.text.trim().split("\n").filter(s => s.length > 0)
            console.log("[wallpaper-switcher] scan done:", root.wallpapers.length, "files — exit:", exitCode)
        }
    }

    Connections {
        target: Config
        function onWallpaperDirChanged() {
            if (Config.wallpaperDir) {
                console.log("[wallpaper-switcher] wallpaperDir:", Config.wallpaperDir)
                console.log("[wallpaper-switcher] wallpaperCmd:", Config.wallpaperCmd)
                scanProcess.running = true
            }
        }
    }

    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function generateHexDisk(count) {
        const results = []

        const dirs = [
            { q: 1, r: 0 },
            { q: 1, r: -1 },
            { q: 0, r: -1 },
            { q: -1, r: 0 },
            { q: -1, r: 1 },
            { q: 0, r: 1 }
        ]

        results.push({ q: 0, r: 0 })

        for (let radius = 1; results.length < count; radius++) {
            let pos = {
                q: dirs[4].q * radius,
                r: dirs[4].r * radius
            }

            for (let side = 0; side < 6; side++) {
                for (let step = 0; step < radius; step++) {
                    if (results.length >= count) break
                    results.push({ q: pos.q, r: pos.r })

                    pos = {
                        q: pos.q + dirs[side].q,
                        r: pos.r + dirs[side].r
                    }
                }
            }
        }

        return results
    }

    function hexToPixel(q, r, radius) {
        const sqrt3 = Math.sqrt(3)
        return {
            x: radius * (3/2 * r),
            y: radius * (sqrt3 * (q + r / 2))
        }
    }

    function computePixelBounds(coords, radius) {
        const sqrt3 = Math.sqrt(3)

        const padX = radius
        const padY = sqrt3 * 0.5 * radius

        let minX =  1e9, maxX = -1e9
        let minY =  1e9, maxY = -1e9

        for (let i = 0; i < coords.length; i++) {
            const c = coords[i]
            const p = hexToPixel(c.q, c.r, radius)

            minX = Math.min(minX, p.x - padX)
            maxX = Math.max(maxX, p.x + padX)
            minY = Math.min(minY, p.y - padY)
            maxY = Math.max(maxY, p.y + padY)
        }

        return { minX, maxX, minY, maxY }
    }

    Process {
        id: applyWallpaperProcess
        property string targetPath: ""
        command: [ "sh", "-c", Config.wallpaperCmd + " " + shellQuote(targetPath) ]

        onRunningChanged: {
            if (running) {
                console.log("[wallpaper-switcher] applying wallpaper:", targetPath)
                console.log("[wallpaper-switcher] full command:", command.join(" "))
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.log("[wallpaper-switcher] process exited — code:", exitCode, "status:", exitStatus)
            if (exitCode !== 0)
                console.warn("[wallpaper-switcher] wallpaperCmd failed for path:", targetPath)
            // Quit ONLY after the command has fully finished, otherwise tearing
            // down the QML engine kills the child process mid-run (matugen etc.).
            Qt.quit()
        }

        stdout: SplitParser {
            onRead: data => console.log("[wallpaper-switcher] stdout:", data)
        }

        stderr: SplitParser {
            onRead: data => console.warn("[wallpaper-switcher] stderr:", data)
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: Colors.surface
        border.width: 2
        border.color: Colors.primary
        z: -1

        focus: true
        Keys.enabled: true

        Component.onCompleted: forceActiveFocus()

        Keys.onEscapePressed: {
            Qt.quit()
        }
        onActiveFocusChanged: {
            // Don't close on focus loss while a wallpaper apply is in flight —
            // that would kill the child process before it finishes.
            if (!activeFocus && !root.applying)
                Qt.quit()
        }
    }

    Item {
        id: hexGrid
        implicitWidth: parent.width
        implicitHeight: parent.height

        anchors.centerIn: parent

        property real hexRadius: {
            const cols = 10
            const rows = 10

            const r1 = width / (1.5 * cols)
            const r2 = height / (Math.sqrt(3) * rows)

            return Math.max(2, Math.min(r1, r2))
        }

        property var bounds: computePixelBounds(root.coords, hexRadius)

        property real offsetX: bounds.minX
        property real offsetY: bounds.minY

        Repeater {
            model: root.coords.length

            delegate: Hex {
                id: hexDelegate

                property var cube: index < root.coords.length ? root.coords[index] : ({ q: 0, r: 0 })

                property real q: cube.q
                property real r: cube.r

                hexRadius: hexGrid.hexRadius

                property var p: hexToPixel(q, r, hexRadius)

                x: (hexGrid.width  - (hexGrid.bounds.maxX - hexGrid.bounds.minX)) / 2 + (p.x - hexGrid.offsetX) - hexGrid.hexRadius * 1

                y: (hexGrid.height - (hexGrid.bounds.maxY - hexGrid.bounds.minY)) / 2 + (p.y - hexGrid.offsetY) - hexGrid.hexRadius * 1

                // Reactive binding: re-evaluates whenever root.wallpapers changes,
                // so a tile can never get stuck empty from a load-timing gap.
                wallpaperPath: (index >= 0 && index < root.wallpapers.length)
                    ? (root.wallpapers[index] || "")
                    : ""

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.applying) return
                        // Use the tile's own resolved path — the exact value the
                        // image rendered — rather than re-indexing the array.
                        const path = hexDelegate.wallpaperPath
                        console.log("[wallpaper-switcher] clicked hex index:", index, "path:", JSON.stringify(path))
                        if (!path) return
                        root.applying = true
                        applyWallpaperProcess.targetPath = path
                        applyWallpaperProcess.running = true
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        scale = hovered ? 1.2 : 1.0
                        z = hovered ? 1 : 0
                    }
                }
            }
        }
    }
}
