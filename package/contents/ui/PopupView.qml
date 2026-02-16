import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Layouts 1.1
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "lib"
import "Shared.js" as Shared
import "./weather/WeatherApi.js" as WeatherApi

	MouseArea {
		id: popup
		readonly property var units: Kirigami.Units
		readonly property var theme: PlasmaCore.Theme

	onClicked: focus = true

	function __debugLayout(reason) {
		if (!plasmoid.configuration.debugging) return
		logger.debug("PopupView.layout", reason,
			"state=", popup.state,
			"popup=", popup.width + "x" + popup.height,
			"cols=", popup.leftColumnWidth + "+" + popup.spacing + "+" + popup.rightColumnWidth,
			"rows=", popup.topRowHeight + "+" + popup.spacing + "+" + popup.bottomRowHeight,
			"grid=", widgetGrid.columns + "x" + widgetGrid.rows,
			"meteogram=", meteogramView.visible + " " + Math.round(meteogramView.width) + "x" + Math.round(meteogramView.height),
			"timer=", timerView.visible + " " + Math.round(timerView.width) + "x" + Math.round(timerView.height)
		)
	}

	Component.onCompleted: {
		// The popup can be created after background polling already fetched weather.
		// Populate the meteogram immediately from cached data (if any).
		if (showMeteogram) {
			updateMeteogram()
		}
		// Log layout once it's been sized.
		Qt.callLater(function() { popup.__debugLayout("completed") })
	}

	property int padding: 0 // Assigned in main.qml
	// QtQuick uses device-independent pixels; don't double-scale with devicePixelRatio.
	property int spacing: units.smallSpacing * 2
	property bool isDesktopContainment: false
	readonly property int topWidgetsCount: (showMeteogram ? 1 : 0) + (showTimer ? 1 : 0)

	property int topRowHeight: plasmoid.configuration.topRowHeight
	property int bottomRowHeight: plasmoid.configuration.bottomRowHeight
	property int singleColumnMonthViewHeight: plasmoid.configuration.monthHeightSingleColumn

	// DigitalClock LeftColumn minWidth: units.gridUnit * 22
	// DigitalClock RightColumn minWidth: units.gridUnit * 14
	// 14/(22+14) * 400 = 156
	// rightColumnWidth=156 looks nice but is very thin for listing events + date + weather.
	property int leftColumnWidth: plasmoid.configuration.leftColumnWidth // Meteogram + AgendaView
	property int rightColumnWidth: plasmoid.configuration.rightColumnWidth // TimerView + MonthView

	property bool singleColumn: !showAgenda || !showCalendar
	property bool singleColumnFullHeight: !plasmoid.configuration.twoColumns && showAgenda && showCalendar && isDesktopContainment
	property bool twoColumns: plasmoid.configuration.twoColumns && showAgenda && showCalendar

	Layout.minimumWidth: {
		if (twoColumns) {
			return units.gridUnit * 28
		} else {
			return units.gridUnit * 14
		}
	}
	Layout.preferredWidth: {
		if (twoColumns) {
			return (leftColumnWidth + spacing + rightColumnWidth) + padding * 2
		} else {
			return leftColumnWidth + padding * 2
		}
	}

	Layout.minimumHeight: units.gridUnit * 14
	Layout.preferredHeight: {
		if (singleColumnFullHeight) {
			return plasmoid.screenGeometry.height
		} else if (singleColumn) {
			var h = bottomRowHeight // showAgenda || showCalendar
			if (showMeteogram) {
				h += spacing + topRowHeight
			}
			if (showTimer) {
				h += spacing + topRowHeight
			}
			return h + padding * 2
		} else { // twoColumns
			var h = bottomRowHeight // showAgenda || showCalendar
			if (showMeteogram || showTimer) {
				h += spacing + topRowHeight
			}
			return h + padding * 2
		}
	}

	property var eventModel
	property var agendaModel

	property bool showMeteogram: plasmoid.configuration.widgetShowMeteogram
	property bool showTimer: plasmoid.configuration.widgetShowTimer
	property bool showAgenda: plasmoid.configuration.widgetShowAgenda
	property bool showCalendar: plasmoid.configuration.widgetShowCalendar
	property bool agendaScrollOnSelect: true
	property bool agendaScrollOnMonthChange: false

	property alias today: monthView.today
	property alias selectedDate: monthView.currentDate
	property alias monthViewDate: monthView.displayedDate

	Connections {
		target: monthView
		function onDateSelected(newDateTime) {
			// logger.debug('onDateSelected', selectedDate)
			scrollToSelection()
		}
	}
	function scrollToSelection() {
		if (!agendaScrollOnSelect) {
			return
		}

		if (true) {
			agendaView.scrollToDate(selectedDate)
		} else {
			agendaView.scrollToTop()
		}
	}

	onMonthViewDateChanged: {
		logger.debug('onMonthViewDateChanged', monthViewDate)
		var startOfMonth = new Date(monthViewDate)
		startOfMonth.setDate(1)
		agendaModel.currentMonth = new Date(startOfMonth)
		if (agendaScrollOnMonthChange) {
			selectedDate = startOfMonth
		}
		logic.updateEvents()
	}

	onStateChanged: {
		// logger.debug(popup.state, widgetGrid.columns, widgetGrid.rows)
		popup.__debugLayout("stateChanged")
	}
	states: [
		State {
			name: "calendar"
			when: !popup.showAgenda && popup.showCalendar && !popup.showMeteogram && !popup.showTimer

				PropertyChanges { target: popup
					// Use the same size as the digitalclock popup
					// since we don't need more space to fit more agenda items.
					Layout.preferredWidth: 378
					Layout.preferredHeight: 378
				}
			PropertyChanges { target: monthView
				Layout.preferredWidth: -1
				Layout.preferredHeight: -1
			}
		},
		State {
			name: "twoColumns+agenda+month"
			when: popup.twoColumns && popup.showAgenda && popup.showCalendar && !popup.showMeteogram && !popup.showTimer

			PropertyChanges { target: widgetGrid
				columns: 2
				rows: 1
			}
		},
		State {
			name: "twoColumns+meteogram+agenda+month"
			when: popup.twoColumns && popup.showAgenda && popup.showCalendar && popup.showMeteogram && !popup.showTimer

			PropertyChanges { target: widgetGrid
				columns: 2
				rows: 2
			}
			PropertyChanges { target: meteogramView
				Layout.columnSpan: 2
			}
		},
			State {
				name: "twoColumns+timer+agenda+month"
				when: popup.twoColumns && popup.showAgenda && popup.showCalendar && !popup.showMeteogram && popup.showTimer

				PropertyChanges { target: widgetGrid
					columns: 2
					rows: 2
				}
				// Make the agenda span both rows (timer + month live in the right column).
				PropertyChanges { target: agendaView
					Layout.row: 0
					Layout.rowSpan: 2
				}
			},
		State {
			name: "twoColumns+meteogram+timer+agenda+month"
			when: popup.twoColumns && popup.showAgenda && popup.showCalendar && popup.showMeteogram && popup.showTimer

			PropertyChanges { target: widgetGrid
				columns: 2
				rows: 2
			}
		},
		State {
			name: "singleColumnFullHeight"
			when: !popup.twoColumns && popup.showAgenda && popup.showCalendar

			PropertyChanges { target: widgetGrid
				columns: 1
				anchors.margins: 0
				anchors.topMargin: popup.padding
			}
			PropertyChanges { target: meteogramView
				Layout.maximumHeight: popup.topRowHeight
			}
			PropertyChanges { target: timerView
				Layout.maximumHeight: popup.topRowHeight
			}
			PropertyChanges { target: monthView
				Layout.minimumHeight: popup.singleColumnMonthViewHeight
				Layout.preferredHeight: popup.singleColumnMonthViewHeight
				Layout.maximumHeight: popup.singleColumnMonthViewHeight
			}
			PropertyChanges { target: agendaView
				// Layout.minimumHeight: popup.bottomRowHeight
				Layout.preferredHeight: popup.bottomRowHeight
			}
		},
		State {
			name: "singleColumn"
			when: !popup.showAgenda || !popup.showCalendar

			PropertyChanges { target: widgetGrid
				columns: 1
			}
				PropertyChanges { target: meteogramView
					Layout.minimumHeight: popup.topRowHeight
					Layout.preferredHeight: popup.topRowHeight * 1.5 // 150%
					Layout.maximumHeight: popup.topRowHeight * 1.5 // 150%
				}
			PropertyChanges { target: timerView
				Layout.maximumHeight: popup.topRowHeight
			}
		}
	]

	GridLayout {
		id: widgetGrid
		anchors.fill: parent
		anchors.margins: popup.padding
		columnSpacing: popup.spacing
		rowSpacing: popup.spacing
		onColumnsChanged: {
			// logger.debug(popup.state, widgetGrid.columns, widgetGrid.rows)
		}
		onRowsChanged: {
			// logger.debug(popup.state, widgetGrid.columns, widgetGrid.rows)
		}


			MeteogramView {
				id: meteogramView
				visible: showMeteogram
				Layout.column: 0
				Layout.row: 0
				Layout.columnSpan: 1
				Layout.fillWidth: true
				Layout.fillHeight: false
				Layout.minimumHeight: popup.topRowHeight
				Layout.preferredWidth: popup.leftColumnWidth
				Layout.preferredHeight: popup.topRowHeight
				Layout.maximumHeight: popup.topRowHeight

				visibleDuration: plasmoid.configuration.meteogramHours
				showIconOutline: plasmoid.configuration.showOutlines
				xAxisScale: 1 / 4
				xAxisLabelEvery: 1
				property int hoursPerDataPoint: WeatherApi.getDataPointDuration(plasmoid.configuration)
				dataPointHours: hoursPerDataPoint
				displayBucketHours: 3
				rainUnits: WeatherApi.getRainUnits(plasmoid.configuration)

			Rectangle {
				id: meteogramMessageBox
				anchors.fill: parent
				anchors.margins: units.smallSpacing
				color: "transparent"
				border.color: theme.buttonBackgroundColor
				border.width: 1

						readonly property string message: {
							if (!WeatherApi.weatherIsSetup(plasmoid.configuration)) {
								return i18n("Weather not configured.\nGo to Weather in the config and set your location,\nand/or disable the meteogram to hide this area.")
							} else if (logic.lastForecastErr) {
								return i18n("Error fetching weather.") + '\n' + logic.lastForecastErr
							} else {
								return ''
							}
				}

				visible: !!message

				PlasmaComponents3.Label {
					text: meteogramMessageBox.message
					anchors.fill: parent
					fontSizeMode: Text.Fit
					wrapMode: Text.Wrap
					horizontalAlignment: Text.AlignHCenter
					verticalAlignment: Text.AlignVCenter
				}
			}
		}

			TimerView {
				id: timerView
				visible: showTimer
				Layout.column: popup.twoColumns ? 1 : 0
				Layout.row: popup.twoColumns ? 0 : (meteogramView.visible ? 1 : 0)
				Layout.fillWidth: true
				Layout.fillHeight: false
				Layout.minimumHeight: popup.topRowHeight
				Layout.preferredWidth: popup.rightColumnWidth
				Layout.preferredHeight: popup.topRowHeight
				Layout.maximumHeight: popup.topRowHeight
			}

			MonthView {
			id: monthView
			visible: showCalendar
				Layout.column: popup.twoColumns ? 1 : 0
				Layout.row: popup.twoColumns ? ((popup.showMeteogram || popup.showTimer) ? 1 : 0) : popup.topWidgetsCount
				// Increase the gap between the timer preset buttons and the calendar header.
				Layout.topMargin: timerView.visible ? popup.spacing : 0
				headingFontScale: 1.5
				calendarGridMargin: units.smallSpacing * 2
				borderOpacity: plasmoid.configuration.monthShowBorder ? 0.25 : 0
				showWeekNumbers: plasmoid.configuration.monthShowWeekNumbers
				highlightCurrentDayWeek: plasmoid.configuration.monthHighlightCurrentDayWeek

		// Bottom row should mirror top row: timer (right) sits above the calendar (right).
			Layout.preferredWidth: popup.twoColumns ? popup.rightColumnWidth : popup.leftColumnWidth
			Layout.preferredHeight: popup.bottomRowHeight
			Layout.fillWidth: true
			Layout.fillHeight: true

			// Component.onCompleted: {
			// 	today = new Date()
			// }

			function parseGCalEvents(data) {
				if (!(data && data.items)) {
					return
				}

				// Clear event data since data contains events from all calendars, and this function
				// is called every time a calendar is recieved.
				for (var i = 0; i < monthView.daysModel.count; i++) {
					var dayData = monthView.daysModel.get(i)
					monthView.daysModel.setProperty(i, 'showEventBadge', false)
					dayData.events.clear()
				}

				// https://github.com/KDE/plasma-framework/blob/master/src/declarativeimports/calendar/daysmodel.h
				for (var j = 0; j < data.items.length; j++) {
					var eventItem = data.items[j]
					var eventItemStartDate = new Date(eventItem.startDateTime.getFullYear(), eventItem.startDateTime.getMonth(), eventItem.startDateTime.getDate())
					var eventItemEndDate = new Date(eventItem.endDateTime.getFullYear(), eventItem.endDateTime.getMonth(), eventItem.endDateTime.getDate())
					if (eventItem.end.date) {
						// All day events end at midnight which is technically the next day.
						eventItemEndDate.setDate(eventItemEndDate.getDate() - 1)
					}
					// logger.debug(eventItemStartDate, eventItemEndDate)
					for (var i = 0; i < monthView.daysModel.count; i++) {
						var dayData = monthView.daysModel.get(i)
						var dayDataDate = new Date(dayData.yearNumber, dayData.monthNumber - 1, dayData.dayNumber)
						if (eventItemStartDate <= dayDataDate && dayDataDate <= eventItemEndDate) {
							// logger.debug('\t', dayDataDate)
							monthView.daysModel.setProperty(i, 'showEventBadge', true)
							var events = dayData.events || []
							events.append(eventItem)
							monthView.daysModel.setProperty(i, 'events', events)
						} else if (eventItemEndDate < dayDataDate) {
							break
						}
					}
				}
			}

			onDayDoubleClicked: {
				var date = new Date(dayData.yearNumber, dayData.monthNumber-1, dayData.dayNumber)
				// logger.debug('Popup.monthView.onDoubleClicked', date)
				var doubleClickOption = plasmoid.configuration.monthDayDoubleClick

				switch (doubleClickOption) {
					case 'GoogleCalWeb':
						Shared.openGoogleCalendarNewEventUrl(date)
						return
					default:
						return
				}
			}
		} // MonthView

			AgendaView {
			id: agendaView
			visible: showAgenda
				Layout.column: 0
				Layout.row: popup.twoColumns ? ((popup.showMeteogram || popup.showTimer) ? 1 : 0) : (popup.topWidgetsCount + (monthView.visible ? 1 : 0))

			// Bottom row should mirror top row: meteogram (left) sits above the agenda (left).
			Layout.preferredWidth: popup.twoColumns ? popup.leftColumnWidth : popup.rightColumnWidth
			Layout.preferredHeight: popup.bottomRowHeight
			Layout.fillWidth: true
			Layout.fillHeight: true

			onNewEventFormOpened: {
				// logger.debug('onNewEventFormOpened')
				var selectedCalendarId = ""
				if (plasmoid.configuration.agendaNewEventRememberCalendar) {
					selectedCalendarId = plasmoid.configuration.agendaNewEventLastCalendarId
				}
				var calendarList = eventModel.getCalendarList()
				calendarSelector.populate(calendarList, selectedCalendarId)
			}
			onSubmitNewEventForm: {
				logger.debug('onSubmitNewEventForm', calendarId)
				eventModel.createEvent(calendarId, date, text)
			}

			MessageWidget {
				id: errorMessageWidget
				anchors.left: parent.left
				anchors.bottom: parent.bottom
				anchors.right: refreshButton.left
				anchors.margins: units.smallSpacing
				text: logic.currentErrorMessage
			}

				PlasmaComponents3.Button {
					id: refreshButton
					icon.name: 'view-refresh'
					anchors.bottom: parent.bottom
					anchors.right: parent.right
					anchors.rightMargin: agendaView.scrollbarWidth
					onClicked: {
						// Refresh agenda + weather together; the user expects the forecast to remain.
						logic.updateEvents()
						logic.updateWeather(true)
					}

				// Timer {
				// 	running: true
				// 	repeat: true
				// 	interval: 2000
				// 	onTriggered: parent.clicked()
				// }
			}
		} // AgendaView
	} // GridLayout

	function updateMeteogram() {
		meteogramView.parseWeatherForecast(logic.currentWeatherData, logic.hourlyWeatherData)
	}

	function showError(msg) {
		errorMessageWidget.warn(msg)
	}

	function clearError() {
		errorMessageWidget.close()
	}

	Timer {
		id: updateUITimer
		interval: 100
		onTriggered: popup.updateUI()
	}
	function deferredUpdateUI() {
		updateUITimer.restart()
	}

		function updateUI() {
			// logger.debug('updateUI')
			var now = new Date()

		if (updateUITimer.running) {
			updateUITimer.running = false
		}

		agendaModel.parseGCalEvents(eventModel.eventsData)
		agendaModel.parseWeatherForecast(logic.dailyWeatherData)
			monthView.parseGCalEvents(eventModel.eventsData)
			scrollToSelection()
		}
	}
