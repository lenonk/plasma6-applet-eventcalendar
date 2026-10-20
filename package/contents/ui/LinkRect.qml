import QtQuick 2.0
import org.kde.plasma.core as PlasmaCore

import "lib"

Rectangle {
	id: linkRect
	width: implicitWidth
	height: implicitHeight
	implicitWidth: childrenRect.width
	implicitHeight: childrenRect.height
	property color backgroundColor: "transparent"
	property color backgroundHoverColor: appletConfig.agendaHoverBackground
	color: linkEnabled && hovered ? backgroundHoverColor : backgroundColor
	property string tooltipMainText
	property string tooltipSubText
	property alias acceptedButtons: mouseArea.acceptedButtons
	property bool linkEnabled: true // Not Item.enabled: children (edit forms) must stay enabled
	readonly property alias hovered: mouseArea.containsMouse

	signal clicked(var mouse)
	signal leftClicked(var mouse)
	signal doubleClicked(var mouse)
	signal loadContextMenu(var contextMenu)
	
	PlasmaCore.ToolTipArea {
		id: tooltip
		anchors.fill: parent
		mainText: linkRect.tooltipMainText
		subText: linkRect.tooltipSubText

		MouseArea {
			id: mouseArea
			anchors.fill: parent
			hoverEnabled: true
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			cursorShape: linkRect.linkEnabled && containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
			enabled: linkRect.linkEnabled
			onClicked: function(mouse) {
				mouse.accepted = false
				linkRect.clicked(mouse)
				if (!mouse.accepted) {
					if (mouse.button == Qt.LeftButton) {
						linkRect.leftClicked(mouse)
					} else if (mouse.button == Qt.RightButton) {
						contextMenu.show(mouse.x, mouse.y)
						mouse.accepted = true
					}
				}
			}
			onDoubleClicked: function(mouse) { linkRect.doubleClicked(mouse) }
		}
	}

	ContextMenu {
		id: contextMenu
		onPopulate: linkRect.loadContextMenu(contextMenu)
	}
}
