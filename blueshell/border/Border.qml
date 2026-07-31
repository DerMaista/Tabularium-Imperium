// Border.qml
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: border

    required property int topheight

    property int screenw: screen.width
    property int screenh: screen.height
    property real uniformMargin: Math.max(Math.min(screenw, screenh) * 0.01, 15 )
    property real strokeWidth: uniformMargin / 6

    implicitHeight: topheight + uniformMargin / 2


    anchors {
        left: true
        right: true
        top: true
    }


    WlrLayershell.layer: WlrLayer.Bottom
    mask: Region {}


    color: "transparent"
}