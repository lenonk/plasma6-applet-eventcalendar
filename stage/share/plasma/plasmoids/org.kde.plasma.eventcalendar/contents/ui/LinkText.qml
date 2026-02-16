import QtQuick 2.0
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore

Label {
	linkColor: PlasmaCore.ColorScope.highlightColor
	onLinkActivated: Qt.openUrlExternally(link)
	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.NoButton // we don't want to eat clicks on the Text
		cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
	}
}
