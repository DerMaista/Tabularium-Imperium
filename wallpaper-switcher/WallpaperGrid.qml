import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.media
import qs.states

Rectangle {
    id: wallpaperGrid
    implicitHeight: 1000
    radius: ThemeManager.radiusLarge
    color: Colors.surface
    border.color: Colors.outline
    border.width: 1
    
    property var wallpaperManager: null
    property var commandExecutor: null
    
    signal applyRequested()
    signal closeRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ThemeManager.spacingMedium
        spacing: ThemeManager.spacingMedium

        // Header
        Text {
            text: "Select Wallpaper"
            font.family: ThemeManager.fontFamily
            font.pixelSize: ThemeManager.fontSizeLarge
            font.weight: Font.Bold
            color: Colors.on_surface
            Layout.alignment: Qt.AlignHCenter
        }

        // Wallpaper grid
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 355
            cellHeight: 200
            clip: true
            model: wallpaperManager ? wallpaperManager.wallpapers : []
            
            delegate: ImageCard {
                width: grid.cellWidth - 10
                height: grid.cellHeight - 10
                imageSource: modelData
                isSelected: wallpaperManager ? wallpaperManager.currentIndex === index : false
                
                onClicked: {
                    if (wallpaperManager) {
                        wallpaperManager.setWallpaper(index)
                    }
                }
                
                onDoubleClicked: {
                    if (wallpaperManager) {
                        wallpaperManager.setWallpaper(index)
                        wallpaperGrid.applyRequested()
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 6
                background: Rectangle { color: "transparent" }
                contentItem: Rectangle {
                    radius: 3
                    color: Colors.outline
                    opacity: 0.6
                }
            }
        }

        // Selected wallpaper info and apply button
        RowLayout {
            Layout.fillWidth: true
            spacing: ThemeManager.spacingMedium

            ColumnLayout {
                Layout.fillWidth: true
                spacing: ThemeManager.spacingSmall

                Text {
                    text: wallpaperManager && wallpaperManager.wallpapers.length > 0 ? 
                          wallpaperManager.getWallpaperName(wallpaperManager.currentIndex) : "No wallpaper selected"
                    font.family: ThemeManager.fontFamily
                    font.pixelSize: ThemeManager.fontSizeMedium
                    color: Colors.on_surface
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                Text {
                    text: wallpaperManager ? 
                          (wallpaperManager.wallpapers.length > 0 ? 
                           (wallpaperManager.currentIndex + 1) + " / " + wallpaperManager.wallpapers.length : 
                           "0 wallpapers") : "Scanning..."
                    font.family: ThemeManager.fontFamily
                    font.pixelSize: ThemeManager.fontSizeSmall
                    color: Colors.on_surface_variant
                    Layout.fillWidth: true
                }
            }

            // Apply button
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 35
                radius: ThemeManager.radiusSmall
                color: applyMouseArea.containsMouse ? Colors.primary : Colors.surface_variant
                border.color: Colors.outline
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: commandExecutor && commandExecutor.executing ? "Applying..." : "Apply"
                    font.family: ThemeManager.fontFamily
                    font.pixelSize: ThemeManager.fontSizeSmall
                    color: applyMouseArea.containsMouse ? Colors.on_primary : Colors.on_surface_variant
                }

                MouseArea {
                    id: applyMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !commandExecutor || !commandExecutor.executing
                    onClicked: wallpaperGrid.applyRequested()
                }
            }
        }
    }
}