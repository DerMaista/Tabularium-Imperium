import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.src.components.basic
import qs.src.components.panels
import qs.src.components.media
import qs.src.globals.states
import qs.src.globals.config


PopupWindow {
    id: musicPopup
    visible: false
    implicitWidth: 500
    implicitHeight: 180
    color: "transparent"
    property bool isHovered: popupHoverHandler.hovered
    property QtObject bar: null
    
    anchor.window: bar
    anchor.rect.x: bar ? bar.width : 0
    anchor.rect.y: bar ? bar.height : 0

    property real progressValue: 0
    property string durationText: "0:00 / 0:00"

    function extractJsonPayload(rawText) {
        var start = rawText.indexOf("{")
        var end = rawText.lastIndexOf("}")
        if (start === -1 || end === -1 || end < start) {
            return ""
        }
        return rawText.slice(start, end + 1)
    }

    HoverHandler {
        id: popupHoverHandler
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 12 
        spacing: 12

        RowLayout {
            spacing: 15
            Layout.fillWidth: true

            AlbumArt {
                id: albumArt
                imageSource: ""
            }

            ColumnLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true

                StyledText {
                    id: trackTitle
                    text: "No Track"
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledText {
                    id: trackArtist
                    text: "Unknown"
                    font.pixelSize: 14
                    color: Colors.on_surface_variant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledText {
                    id: progressText
                    text: durationText
                    font.pixelSize: 12
                    color: Colors.on_surface_variant
                    Layout.fillWidth: true
                }
            }
        }  
        
        ProgressBar {
            id: progressBar
            Layout.fillWidth: true
            progress: musicPopup.progressValue
            
            onSeekRequested: function(position) {
                seekProc.running = true
            }
        }

        MediaControls {
            id: mediaControls
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            
            onPlayPauseClicked: playPauseProc.running = true
            onNextClicked: nextProc.running = true
            onPreviousClicked: prevProc.running = true
        }
    }

    Process {
        id: statusProc
        command: ["hydractl", "music", "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var rawOutput = this.text.trim()

                    if (rawOutput === "") {
                        Qt.callLater(() => {
                            spotifyStarter.running = true
                            statusProc.running = true
                        })
                        return
                    }

                    var jsonPayload = musicPopup.extractJsonPayload(rawOutput)
                    if (jsonPayload === "") {
                        return
                    }

                    var data = JSON.parse(jsonPayload)
                    trackTitle.text = data.title || "No Track"
                    trackArtist.text = data.artist || "Unknown"
                    albumArt.imageSource = data.albumArt || ""
                    mediaControls.isPlaying = data.playing
                    albumArt.isPlaying = data.playing

                    var progress = data.position / Math.max(data.length, 1)
                    progressValue = Math.min(Math.max(progress, 0), 1)

                    var currentTime = formatTime(data.position || 0)
                    var totalTime = formatTime(data.length || 0)
                    durationText = currentTime + " / " + totalTime
                    
                } catch(e) {
                    return
                }
            }
        }
    }

    function formatTime(seconds) {
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" + secs : secs)
    }

    Process {
        id: spotifyStarter
        command: ["bash", "-c", "pgrep -x spotify >/dev/null || spotify &"]
        running: false
    }

    Process { id: playPauseProc; command: ["hydractl", "music", "play-pause"] }
    Process { id: nextProc; command: ["hydractl", "music", "next"] }
    Process { id: prevProc; command: ["hydractl", "music", "previous"] }
    Process { id: seekProc; command: ["bash", "-c", "playerctl position `playerctl metadata --format '{{duration}}'`"] }

    Timer {
        interval: 1000  
        running: musicPopup.visible
        repeat: true
        onTriggered: statusProc.running = true
    }

    onVisibleChanged: {
        if (visible) {
            statusProc.running = true
        }
    }

    Component.onCompleted: {
        //spotifyStarter.running = true
        statusProc.running = true
    }
}