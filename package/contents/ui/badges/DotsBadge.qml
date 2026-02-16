import QtQuick 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

Item {
	id: dotsBadge
	readonly property var units: Kirigami.Units
	property int dotSize: (height / 8) + dotBorderWidth*2
	property color dotColor: PlasmaCore.Theme.highlightColor
	property int dotBorderWidth: plasmoid.configuration.showOutlines ? 1 : 0
	property color dotBorderColor: PlasmaCore.Theme.backgroundColor

	Row {
		anchors.horizontalCenter: dotsBadge.horizontalCenter
		anchors.bottom: dotsBadge.bottom
		anchors.margins: dotsBadge.height / 8
		spacing: units.smallSpacing

		Rectangle {
			visible: modelEventsCount >= 1
			width: dotsBadge.dotSize
			height: dotsBadge.dotSize
			radius: width / 2
			color: dotsBadge.dotColor
			border.width: dotsBadge.dotBorderWidth
			border.color: dotsBadge.dotBorderColor
		}
		Rectangle {
			visible: modelEventsCount >= 2
			width: dotsBadge.dotSize
			height: dotsBadge.dotSize
			radius: width / 2
			color: dotsBadge.dotColor
			border.width: dotsBadge.dotBorderWidth
			border.color: dotsBadge.dotBorderColor
		}
		Rectangle {
			visible: modelEventsCount >= 3
			width: dotsBadge.dotSize
			height: dotsBadge.dotSize
			radius: width / 2
			color: dotsBadge.dotColor
			border.width: dotsBadge.dotBorderWidth
			border.color: dotsBadge.dotBorderColor
		}
	}
}
