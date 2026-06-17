import QtQuick
import QtQuick.Controls 
import QtQuick.Layouts
import qs.src.globals.states

Rectangle {
    id: searchBar
    implicitHeight: 50
    
    property alias placeholderText: textField.placeholderText
    property alias text: textField.text
    
    radius: ThemeManager.radiusMedium
    color: Colors.surface_variant
    border.color: Colors.outline
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: ThemeManager.spacingMedium
        spacing: ThemeManager.spacingMedium

        Text {
            text: "🔍"
            font.pixelSize: ThemeManager.fontSizeLarge
            Layout.alignment: Qt.AlignVCenter
        }

        TextField {
            id: textField
            Layout.fillWidth: true
            placeholderText: searchBar.placeholderText
            font.family: ThemeManager.fontFamily
            font.pixelSize: ThemeManager.fontSizeMedium
            background: Rectangle { color: "transparent" }
            onTextChanged: searchBar.textChanged(text)
        }
    }
}