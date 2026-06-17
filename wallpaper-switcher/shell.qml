import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.basic
import qs.states
PanelWindow {
    id: wallpaperSwitcher
    visible: true
    implicitWidth: 600
    implicitHeight: 500
    color: "transparent"

    // Managers
    WallpaperManager { id: wallpaperManager }
    WallpaperCommands { id: commandExecutor }

    ModalOverlay {
        anchors.fill: parent
        shown: wallpaperSwitcher.visible
        onClicked: wallpaperSwitcher.visible = false
    }

    WallpaperGrid {
        id: wallpaperGrid
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 600)
        height: Math.min(parent.height * 0.9, 500)
        wallpaperManager: wallpaperManager
        commandExecutor: commandExecutor
        
        onApplyRequested: {
            if (wallpaperManager.currentWallpaper) {
                commandExecutor.applyWallpaper(wallpaperManager.currentWallpaper, wallpaperManager.symlinkPath)
            }
        }
    }

    CloseButton {
        anchors {
            top: wallpaperGrid.top
            right: wallpaperGrid.right
            margins: 8
        }
        onClicked: wallpaperSwitcher.visible = false
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: wallpaperSwitcher.visible

        Keys.onPressed: {
            if (!wallpaperSwitcher.visible) return

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (wallpaperManager.currentWallpaper) {
                    commandExecutor.applyWallpaper(wallpaperManager.currentWallpaper, wallpaperManager.symlinkPath)
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                wallpaperSwitcher.visible = false
                event.accepted = true
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            console.log("Wallpaper switcher shown - scanning wallpapers")
            wallpaperManager.scanWallpapers()
            keyHandler.forceActiveFocus()
        } else {
            Qt.quit()
        }
    }

    Connections {
        target: wallpaperManager
        function onScanError(error) {
            console.error("Wallpaper scan error:", error)
        }
    }

    Connections {
        target: commandExecutor
        function onAllCommandsFinished() {
            console.log("Wallpaper applied successfully")
            wallpaperSwitcher.visible = false
        }
    }

    IpcHandler {
        target: "wallpaper-switcher"
        function toggle(): void { wallpaperSwitcher.visible = !wallpaperSwitcher.visible }
    }

}