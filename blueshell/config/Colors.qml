pragma Singleton
import Quickshell.Io
import QtQuick
import Quickshell

Singleton {
    id: root

    FileView {
        id: file
        //TODO: make this path relative ot based on xdg config dir
        path: "/home/christoph/repos/Tabularium-Imperium/blueshell/config/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property string background
            property string primary
            property string accent
        }
    }


        property alias background: adapter.background
        property alias primary: adapter.primary
        property alias accent: adapter.accent
}