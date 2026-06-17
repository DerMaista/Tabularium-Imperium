import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.src.components.basic
import qs.src.globals.states

Scope {
	id: root

	property bool shouldShowOsd: false
	property int brightnessValue: 0
	property int maxBrightnessValue: 100
	property int previousBrightnessValue: -1
	property bool hasLoadedBrightness: false

	readonly property real brightnessRatio: {
		if (maxBrightnessValue <= 0)
			return 0;
		return Math.max(0, Math.min(1, brightnessValue / maxBrightnessValue));
	}

	Timer {
		id: hideTimer
		interval: 1000
		onTriggered: root.shouldShowOsd = false
	}

	FileView {
		id: maxBrightnessFile

		path: "/sys/class/backlight/intel_backlight/max_brightness"
		onLoaded: {
			const parsed = parseInt(text().trim(), 10);
			if (!isNaN(parsed) && parsed > 0)
				root.maxBrightnessValue = parsed;
		}
	}

	FileView {
		id: brightnessFile

		path: "/sys/class/backlight/intel_backlight/actual_brightness"
		watchChanges: true
		onFileChanged: this.reload()
		onLoaded: {
			const parsed = parseInt(text().trim(), 10);
			if (isNaN(parsed))
				return;

			const changed = root.hasLoadedBrightness && parsed !== root.previousBrightnessValue;

			root.brightnessValue = parsed;
			root.previousBrightnessValue = parsed;
			root.hasLoadedBrightness = true;

			if (changed) {
				root.shouldShowOsd = true;
				hideTimer.restart();
			}
		}
	}

	LazyLoader {
		active: root.shouldShowOsd

		PanelWindow {
			anchors.bottom: true
			margins.bottom: screen.height / 5
			exclusiveZone: 0

			implicitWidth: 400
			implicitHeight: 50
			color: "transparent"

			mask: Region {}

			Rectangle {
				anchors.fill: parent
				radius: height / 2
				color: Colors.surface

				RowLayout {
					anchors {
						fill: parent
						leftMargin: 10
						rightMargin: 15
					}

					StyledText {
						text: "󰃠"
						font.pixelSize: parent.height * 0.5
						font.bold: true
					}

					Rectangle {
						Layout.fillWidth: true

						implicitHeight: 10
						radius: 20
						color: Colors.surface_variant

						Rectangle {
							anchors {
								left: parent.left
								top: parent.top
								bottom: parent.bottom
							}

							implicitWidth: parent.width * root.brightnessRatio
							radius: parent.radius
							color: Colors.primary
						}
					}
				}
			}
		}
	}
}
