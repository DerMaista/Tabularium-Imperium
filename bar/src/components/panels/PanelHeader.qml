import QtQuick
import QtQuick.Layouts
import qs.src.globals.states
import qs.src.globals.config

Rectangle {
    id: header
    implicitHeight: 40
    color: "transparent"
    
    property string title: "Panel"
    property bool showActionButton: false
    property string actionText: "Action"
    
    signal actionClicked()
    
    RowLayout {
        anchors.fill: parent
        spacing: ThemeManager.spacingMedium

        Text {
            text: header.title
            font.family: ThemeManager.fontFamily
            font.pixelSize: ThemeManager.fontSizeLarge
            font.weight: Font.Medium
            color: Colors.on_surface
            Layout.fillWidth: true
        }

        Rectangle {
            visible: header.showActionButton
            radius: ThemeManager.radiusSmall
            color: Colors.primary
            width: 80
            height: 28

            Text {
                anchors.centerIn: parent
                text: header.actionText
                color: Colors.on_primary
                font.family: ThemeManager.fontFamily
                font.pixelSize: ThemeManager.fontSizeSmall
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: header.actionClicked()
            }
        }
    }
}