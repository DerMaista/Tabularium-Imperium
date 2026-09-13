import QtQuick

import qs.config

Text {
    property bool accent: false

    color: accent ? Colors.accent : Colors.primary
    font.pixelSize: Config.fontsize
    font.family: Config.fontfamily
}
