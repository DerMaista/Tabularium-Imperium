import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel

import qs.config

PanelWindow {
    id: root
    visible: true
    color: "transparent"

    implicitWidth: 1000 
    implicitHeight: 1000 

    focusable: true
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property var coords: generateHexDisk(folderModel.count)

    Connections {
        target: folderModel
        function onCountChanged() {
            root.rebuildCoords()
        }
    }

    function rebuildCoords() {
        coords = generateHexDisk(folderModel.count)
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

    Rectangle {
        id: background
        anchors.fill: parent
        color: Colors.surface
        border.width: 2
        border.color: Colors.primary

        focus: true
        Keys.enabled: true

        Component.onCompleted: forceActiveFocus()

        Keys.onEscapePressed: {
            Qt.quit()
        }
        onActiveFocusChanged: {
            
            if (!activeFocus)
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
            model: folderModel

            delegate: Hex {
                property bool valid: index < root.coords.length
                visible: valid

                property var cube: valid ? root.coords[index] : ({ q: 0, r: 0 })

                property real q: cube.q
                property real r: cube.r

                hexRadius: hexGrid.hexRadius

                property var p: hexToPixel(q, r, hexRadius)

                x: (hexGrid.width  - (hexGrid.bounds.maxX - hexGrid.bounds.minX)) / 2 + (p.x - hexGrid.offsetX) - hexGrid.hexRadius * 1

                y: (hexGrid.height - (hexGrid.bounds.maxY - hexGrid.bounds.minY)) / 2 + (p.y - hexGrid.offsetY) - hexGrid.hexRadius * 1

                wallpaperPath: filePath

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        applyWallpaperProcess.running = true
                        Qt.quit()
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        scale = hovered ? 1.2 : 1.0
                        z = hovered ? 1 : 0
                    }
                }
                Process {
                    id: applyWallpaperProcess
                    command: [ "sh", "-c", "notify-send 'Applying wallpaper' '" + wallpaperPath + "' && " + Config.wallpaperCmd + " '" + wallpaperPath + "'" ]
                }
            }
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + Config.wallpaperDir || ""
        nameFilters: ["*.png", "*.jpg"]
        showDirs: false
    }
}