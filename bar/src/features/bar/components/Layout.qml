import Quickshell
import Quickshell.Io
import QtQuick

import qs.src.components.basic
import qs.src.globals.states

StyledText {
    id: layout
    property string cLayout
    font.pixelSize: ThemeManager.fontSizeLarge

    text: "[" + cLayout + "]"

    MouseArea {
        anchors.fill: parent
        onClicked: {
            Quickshell.execDetached(["mmsg", "-d", "switch_layout"])
        }
    }

    Process {
        id: gloProc
        running: true
        command: ["sh", "-c", "mmsg -w -l"]  // watch mode

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var match = data.match(/^\S+ layout (\S+)/)
                if (!match) return

                var layoutSymbol = match[1]

                if (layoutSymbol === layout.cLayout)
                    return  // ignore duplicates

                layout.cLayout = layoutSymbol
            }
        }
    }
}