import QtQuick 2.0
import QtQuick.Layouts 1.1

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.digitalclock as DigitalClock

import "./lib"

PlasmoidItem {
	id: root

	Logger {
		id: logger
		name: 'eventcalendar'
		showDebug: plasmoid.configuration.debugging
		// showDebug: true
	}

	ConfigMigration { id: configMigration }
	AppletConfig { id: appletConfig }
	NotificationManager { id: notificationManager }
	NetworkMonitor { id: networkMonitor }

	property alias eventModel: eventModel
	property alias agendaModel: agendaModel
	
	TimeModel { id: timeModel }
	TimerModel { id: timerModel }
	EventModel { id: eventModel }
	UpcomingEvents { id: upcomingEvents }
	AgendaModel {
		id: agendaModel
		eventModel: eventModel
		timeModel: timeModel
		Component.onCompleted: logger.debug('AgendaModel.onCompleted')
	}
	Logic { id: logic }

	FontLoader {
		source: "../fonts/weathericons-regular-webfont.ttf"
	}

	Connections {
		target: plasmoid
		function onContextualActionsAboutToShow() {
			DigitalClock.ClipboardMenu.currentDate = timeModel.currentTime
		}
	}

	toolTipItem: Loader {
		id: tooltipLoader

		Layout.minimumWidth: item ? item.width : 0
		Layout.maximumWidth: item ? item.width : 0
		Layout.minimumHeight: item ? item.height : 0
		Layout.maximumHeight: item ? item.height : 0

		source: "TooltipView.qml"
	}

	// org.kde.plasma.mediacontrollercompact
	Plasma5Support.DataSource {
		id: executable
		engine: "executable"
		connectedSources: []
		onNewData: disconnectSource(sourceName) // cmd finished
		function getUniqueId(cmd) {
			// Note: we assume that 'cmd' is executed quickly so that a previous call
			// with the same 'cmd' has already finished (otherwise no new cmd will be
			// added because it is already in the list)
			// Workaround: We append spaces onto the user's command to workaround this.
			var cmd2 = cmd
			for (var i = 0; i < 10; i++) {
				if (executable.connectedSources.includes(cmd2)) {
					cmd2 += ' '
				}
			}
			return cmd2
		}
		function exec(cmd) {
			connectSource(getUniqueId(cmd))
		}
	}

	property Component clockComponent: ClockView {
		id: clock

		currentTime: timeModel.currentTime

		MouseArea {
			id: mouseArea
			anchors.fill: parent

			property int wheelDelta: 0

			onClicked: {
				if (mouse.button == Qt.LeftButton) {
					root.expanded = !root.expanded
				}
			}

			onWheel: {
				var delta = wheel.angleDelta.y || wheel.angleDelta.x
				wheelDelta += delta

				// Magic number 120 for common "one click"
				// See: https://doc.qt.io/qt-5/qml-qtquick-wheelevent.html#angleDelta-prop
				while (wheelDelta >= 120) {
					wheelDelta -= 120
					onScrollUp()
				}
				while (wheelDelta <= -120) {
					wheelDelta += 120
					onScrollDown()
				}
			}

			function onScrollUp() {
				if (plasmoid.configuration.clockMouseWheel === 'RunCommands') {
					executable.exec(plasmoid.configuration.clockMouseWheelUp)
				}
			}
			function onScrollDown() {
				if (plasmoid.configuration.clockMouseWheel === 'RunCommands') {
					executable.exec(plasmoid.configuration.clockMouseWheelDown)
				}
			}
		}
	}

	property Component popupComponent: PopupView {
		id: popup

		eventModel: root.eventModel
		agendaModel: root.agendaModel

		// If pin is enabled, we need to add some padding around the popup unless
		// * we're a desktop widget (no need)
		// * the timer widget is enabled since there's room in the top right
		property bool isPinVisible: {
			// plasmoid.location == PlasmaCore.Types.Floating when using plasmawindowed and when used as a desktop widget.
			return root.location != PlasmaCore.Types.Floating // && plasmoid.configuration.widget_show_pin
		}
		padding: {
			if (isPinVisible && !(plasmoid.configuration.widgetShowTimer || plasmoid.configuration.widgetShowMeteogram)) {
				return pinButton.height
			} else {
				return 0
			}
		}

		property bool isExpanded: root.expanded
		onIsExpandedChanged: {
			logger.debug('isExpanded', isExpanded)
			if (isExpanded) {
				updateToday()
				logic.updateWeather()
			}
		}

		function updateToday() {
			setToday(timeModel.currentTime)
		}

		function setToday(d) {
			logger.debug('setToday', d)
			today = d
			// console.log(root.timezone, dataSource.data[root.timezone]["DateTime"])
			logger.debug('currentTime', timeModel.currentTime)
			monthViewDate = today
			selectedDate = today
			scrollToSelection()
		}

		Connections {
			target: timeModel
			onDateChanged: {
				popup.updateToday()
				logger.debug('root.onDateChanged', timeModel.currentTime, popup.today)
			}
		}

		Binding {
			target: root
			property: "hideOnWindowDeactivate"
			value: !plasmoid.configuration.pin
		}

		// Allows the user to keep the calendar open for reference
		PlasmaComponents3.ToolButton {
			id: pinButton
			visible: isPinVisible
			anchors.right: parent.right
			width: Math.round(units.gridUnit * 1.25)
			height: width
			checkable: true
			icon.name: "window-pin"
			checked: plasmoid.configuration.pin
			onCheckedChanged: plasmoid.configuration.pin = checked
		}

	}

	backgroundHints: plasmoid.configuration.showBackground ? PlasmaCore.Types.DefaultBackground : PlasmaCore.Types.NoBackground

	property bool isDesktopContainment: root.location == PlasmaCore.Types.Floating
	preferredRepresentation: isDesktopContainment ? fullRepresentation : compactRepresentation
	compactRepresentation: clockComponent
	fullRepresentation: popupComponent

	Component.onCompleted: {
		if (typeof plasmoid !== "undefined" && typeof plasmoid.setAction === "function" && typeof plasmoid.action === "function") {
			plasmoid.setAction("clipboard", i18nd("plasma_applet_org.kde.plasma.digitalclock", "Copy to Clipboard"), "edit-copy")
			DigitalClock.ClipboardMenu.setupMenu(plasmoid.action("clipboard"))
		}

		// plasmoid.action("configure").trigger()
	}

	// Timer {
	// 	interval: 400
	// 	running: true
	// 	onTriggered: {
	// 		plasmoid.expanded = true
	// 		root.plasmoid.fullRepresentationItem.Layout.minimumWidth = 1000
	// 		root.plasmoid.fullRepresentationItem.Layout.minimumHeight = 600
	// 	}
	// }
}
