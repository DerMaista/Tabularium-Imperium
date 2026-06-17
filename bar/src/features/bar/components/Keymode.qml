import Quickshell
import Quickshell.Io
import QtQuick

import qs.src.components.basic
import qs.src.globals.states

StyledText {
    id: layout
    property string cKeymode
    font.pixelSize: ThemeManager.fontSizeMedium

    text: "[" + cKeymode + "]"

    Process {
        id: gkmProc
        running: true
        command: ["sh", "-c", "mmsg -w -b"]  // watch mode

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var match = data.match(/^\S+ keymode (\S+)/)
                if (!match) return

                var keymodeSymbol = match[1]

                if (keymodeSymbol === layout.cKeymode)
                    return  // ignore duplicates

                layout.cKeymode = keymodeSymbol
            }
        }
    }
}