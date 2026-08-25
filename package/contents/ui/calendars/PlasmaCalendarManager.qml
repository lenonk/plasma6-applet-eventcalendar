import QtQuick 2.0

import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

import "../lib"
import "../Shared.js" as Shared
import "../calendars/PlasmaCalendarUtils.js" as PlasmaCalendarUtils

CalendarManager {
	id: plasmaCalendarManager

	calendarManagerId: "plasma"

	property var executable: ExecUtil { id: executable }
	property var eventPluginsManager: PlasmaCalendar.EventPluginsManager {}
	property var calendarModel: Qt.createQmlObject("import org.kde.plasma.PimCalendars 1.0; PimCalendarsModel {}", plasmaCalendarManager)

	// PimEventsConfig / pimcalendarsmodel role IDs (kdepim-addons pimeventsplugin):
	//   CollectionIdRole = Qt.UserRole + 1  (257) -> qint64
	//   NameRole         = Qt.UserRole + 2  (258) -> QString
	//   EnabledRole      = Qt.UserRole + 3  (259) -> bool
	//   CheckedRole      = Qt.UserRole + 4  (260) -> bool
	//   IconNameRole     = Qt.UserRole + 5  (261) -> QString
	// data(idx, Qt.UserRole + 1) returns a scalar qint64, NOT a map.
	// "enabled" only means the collection has a calendar/todo mime type
	// (a prerequisite); the user toggle signal is "checked".
	function appendPimCalendars(calendarList) {
		// https://github.com/KDE/kdepim-addons/blob/master/plugins/plasma/pimeventsplugin/PimEventsConfig.qml
		// https://github.com/KDE/kdepim-addons/blob/master/plugins/plasma/pimeventsplugin/pimcalendarsmodel.cpp

		if (!calendarModel) {
			logger.debug('KDEPIM Not installed as PimCalendarsModel import failed.', calendarModel)
			return
		}
		if (typeof calendarModel.rowCount !== "function") {
			logger.debug('PimCalendarsModel.rowCount missing, skipping.')
			return
		}

		logger.debug('calendarModel', calendarModel)
		logger.debug('PimCalendarsModel.count', calendarModel.rowCount())
		var role = {
			DisplayRole: 0,
			CollectionIdRole: Qt.UserRole + 1,
			NameRole: Qt.UserRole + 2,
			EnabledRole: Qt.UserRole + 3,
			CheckedRole: Qt.UserRole + 4,
			IconNameRole: Qt.UserRole + 5,
		}

		function pushCalendar(index, indentPrefix) {
			var akonadiId = calendarModel.data(index, role.CollectionIdRole)
			if (typeof akonadiId === "undefined" || akonadiId === null) return
			akonadiId = "" + akonadiId
			var displayName = calendarModel.data(index, role.NameRole)
				|| calendarModel.data(index, role.DisplayRole)
			var isCalendar = !!calendarModel.data(index, role.EnabledRole)
			var isChecked = !!calendarModel.data(index, role.CheckedRole)
			var iconName = calendarModel.data(index, role.IconNameRole) || ""
			logger.debugJSON('PimCalendarsModel', indentPrefix, displayName, {
				id: akonadiId,
				isEnabled: isCalendar,
				isChecked: isChecked,
				iconName: iconName,
			})
			if (!isCalendar || !isChecked) return
			calendarList.push({
				"id": "plasma_Events_" + akonadiId,
				"summary": displayName || ("Calendar " + akonadiId),
				"accessRole": "owner",
				"isTasklist": false,
			})
		}

		for (var i = 0; i < calendarModel.rowCount(); i++) {
			var topIndex = calendarModel.index(i, 0)
			pushCalendar(topIndex, String(i))

			if (calendarModel.hasChildren && calendarModel.hasChildren(topIndex)) {
				for (var j = 0; j < calendarModel.rowCount(topIndex); j++) {
					var childIndex = calendarModel.index(j, 0, topIndex)
					pushCalendar(childIndex, i + "." + j)
				}
			}
		}
	}

	//--- CalendarManager
	function getCalendarList() {
		var calendarList = []

		// KHolidays
		calendarList.push({
			"calendarId": "plasma_Holidays",
			"accessRole": "reader",
			"isTasklist": false,
		})

		// KDEPIM
		appendPimCalendars(calendarList)

		return calendarList
	}

	// https://github.com/KDE/plasma-framework/blob/master/src/declarativeimports/calendar/eventpluginsmanager.cpp
	// Plugins are located at:
	//     * (Ubuntu) /usr/lib/x86_64-linux-gnu/qt5/plugins/plasmacalendarplugins/
	//     * (Arch) /usr/lib/qt/plugins/plasmacalendarplugins/
	// DigitalClock's config in ~/.config/plasma-____-appletsrc is:
	//   enabledCalendarPlugins=/usr/lib/.../plugins/plasmacalendarplugins/holidaysevents.so
	// Holidays stores the region in:
	//   ~/.config/plasma_calendar_holiday_regions
	//     [General]
	//     selectedRegions=us_en-us,ru_ru

	// PlasmaCalendar.EventPluginsManager.model is EventPluginsManager::pluginsModel()
	// Which is only useful for the config to select the plugins.
	// We need EventPluginsManager::plugins() to iterate the plugins, but it isn't exposed to QML.
	// So we need to use PlasmaCalendar.Calendar which has a DaysModel property that has a function
	// to get a list of events for a specific day.

	Component.onCompleted: {
		applyEnabledPlugins()
	}
	Connections {
		target: plasmoid.configuration
		function onEnabledCalendarPluginsChanged() {
			applyEnabledPlugins()
		}
	}
	function applyEnabledPlugins() {
		PlasmaCalendarUtils.setEnabledPluginsByFilename(eventPluginsManager, plasmoid.configuration.enabledCalendarPlugins)
		// Force a refresh so newly enabled plugins (eg: astronomical events) show up immediately.
		Qt.callLater(function() {
			if (calendarBackend) {
				calendarBackend.updateData()
			}
			plasmaCalendarManager.refresh()
		})
	}

	// From: kdeclarative/.../MonthView.qml
	PlasmaCalendar.Calendar {
		id: calendarBackend

		days: 7
		weeks: 6
		firstDayOfWeek: {
			if (plasmoid.configuration.firstDayOfWeek == -1) {
				return Qt.locale().firstDayOfWeek
			} else {
				return plasmoid.configuration.firstDayOfWeek
			}
		}
		today: timeModel.currentTime

		Component.onCompleted: {
			//daysModel.connect
			if (daysModel && eventPluginsManager) {
				daysModel.setPluginsManager(eventPluginsManager)
			}
		}
	}

	readonly property string translatedHolidaysType: i18nc("Agenda listview section title", "Holidays")
	readonly property string translatedEventsType: i18nc("Agenda listview section title", "Events")
	readonly property string translatedTodoType: i18nc("Agenda listview section title", "Todo")
	readonly property string translatedOtherType: i18nc("Means 'Other calendar items'", "Other")
	function parseCalendarId(dayItem) {
		// dayItem.eventType is translated, but is the only way to tell which plugin it belongs to without
		// creating a seperate PlasmaCalendar.EventPluginsManager for each plugin (assuming it's not a singleton).
		// https://github.com/KDE/plasma-framework/blob/master/src/declarativeimports/calendar/eventdatadecorator.cpp#L60
		// plasma-framework uses the "libplasma5" translation domain.
		if (dayItem.eventType == translatedHolidaysType) {
			return calendarManagerId + "_Holidays"
		} else if (dayItem.eventType == translatedEventsType) {
			return calendarManagerId + "_Events"
		} else if (dayItem.eventType == translatedTodoType) {
			return calendarManagerId + "_Todo"
		} else if (dayItem.eventType == translatedOtherType) {
			return calendarManagerId + "_Other"
		} else {
			return calendarManagerId + "_NotImplemented"
		}
	}

	function parseEventsForDate(day, dayEvents) {
		var items = []
		for (var i = 0; i < dayEvents.length; i++) {
			var dayItem = dayEvents[i]
			// logger.log(JSON.stringify(dayItem, null, '\t'))

			var start = {}
			var end = {}

			// The dayItem.___DateTime might be "Invalid Date"
			// Eg: the "Astronomical Events" plugin
			var startDateTime = new Date(Shared.isValidDate(dayItem.startDateTime) ? dayItem.startDateTime : day)
			var endDateTime = new Date(Shared.isValidDate(dayItem.endDateTime) ? dayItem.endDateTime : day)
			// logger.log('\t startDateTime', dayItem.startDateTime, startDateTime)
			// logger.log('\t endDateTime', dayItem.endDateTime, endDateTime)
			
			if (dayItem.isAllDay) {
				start.date = Shared.localeDateString(startDateTime) // 2018-01-31
				// Google Calendar has the event start at midnight, and end at midnight the next day
				// Plasma has the date end on the same day, so we need to add 1 day to it so
				// the rest of our code stack works.
				var endDate = new Date(endDateTime)
				endDate.setDate(endDate.getDate() + 1)
				end.date = Shared.localeDateString(endDate) // 2018-01-31
				endDateTime = new Date(end.date)
			} else {
				start.dateTime = startDateTime
				end.dateTime = endDateTime
			}
			var calendarId = parseCalendarId(dayItem)
			// dayItem.uid for PimCalendar-sourced events is "Akonadi-<itemId>".
			var stableSuffix = dayItem.uid
				? dayItem.uid
				: (startDateTime.getTime() + "_" + endDateTime.getTime() + "_" + i)
			var eventId = calendarId + "_" + stableSuffix

			var eventColor = dayItem.eventColor || Kirigami.Theme.highlightColor
			eventColor = "" + eventColor // Cast to string, as dayItem.eventColor is a QColor which JSON treats as an object

			var event = {
				"id": eventId,
				"calendarId": calendarId,
				"htmlLink": "",
				"summary": dayItem.title,
				"description": dayItem.description,
				"start": start,
				"end": end,
				"backgroundColor": eventColor,
			}
			items.push(event)
		}
		return items
	}

	function filterEventsIntoCalendars() {

	}

	function getEventsForDate(date) {
		var dayEvents = calendarBackend.daysModel.eventsForDate(date)
		return parseEventsForDate(date, dayEvents)
	}

	function getEventsForDuration(dateMin, dateMax) {
		var numDays = 0
		for (var day = new Date(dateMin); day < dateMax; day.setDate(day.getDate() + 1)) {
			numDays += 1
		}
		// CalendarBackend needs the actual month we're looking at. We can't arbitrarily grab events for random days.
		var middleDay = new Date(dateMin)
		middleDay.setDate(middleDay.getDate() + Math.floor(numDays/2))
		calendarBackend.displayedDate = middleDay

		var items = []
		
		// 2018-05-24T00:00:00.000Z
		var dateMinUtcStr = Shared.localeDateString(dateMin) + 'T00:00:00.000Z'
		var dateMinUtc = new Date(dateMinUtcStr)
		// logger.debug('getEventsForDuration.dateMinUtcStr', dateMinUtcStr)
		// logger.debug('getEventsForDuration.dateMinUtc', dateMinUtc)

		for (var day = new Date(dateMinUtc); day < dateMax; day.setDate(day.getDate() + 1)) {
			var dayEvents = calendarBackend.daysModel.eventsForDate(day)
			if (dayEvents.length) {
				logger.debugJSON('PlasmaCalendar', day, dayEvents)
			}
			items = items.concat(parseEventsForDate(day, dayEvents))
		}
		// logger.debugJSON(items)

		// We need to filter out the repeated items for multi-day events as Plasma creates a new "event item"
		// for each day of the event.
		for (var i = 0; i < items.length; i++) {
			var itemA = items[i]

			// Check every event before this one.
			for (var j = 0; j < i; j++) {
				var itemB = items[j]
				if (itemA.id == itemB.id) {
					// Same id means either the same event on the same day
					// (Plasma fans out one entry per day of a multi-day event),
					// or two distinct events that happen to collide. Keep them
					// both: the agenda already shows them correctly.

					var startDateA = itemA.start && itemA.start.dateTime
						? itemA.start.dateTime.getTime()
						: (itemA.start && itemA.start.date
							? new Date(itemA.start.date).getTime()
							: 0)
					var startDateB = itemB.start && itemB.start.dateTime
						? itemB.start.dateTime.getTime()
						: (itemB.start && itemB.start.date
							? new Date(itemB.start.date).getTime()
							: 0)

					if (startDateA == startDateB) {
						// Same id AND same start -> dup of multi-day fan-out.
						items.splice(i, 1)
						i -= 1
					}
					break
				}
			}
		}

		return items
	}



	onFetchAllCalendars: {
		var allEvents = getEventsForDuration(dateMin, dateMax)

		// Filter events into seperate calendars
		var calendarIdList = []
		var calendars = {}
		for (var i = 0; i < allEvents.length; i++) {
			var event = allEvents[i]
			if (calendarIdList.indexOf(event.calendarId) == -1) {
				calendarIdList.push(event.calendarId)
				calendars[event.calendarId] = []
			}
			calendars[event.calendarId].push(event)
		}
		for (var i = 0; i < calendarIdList.length; i++) {
			var calendarId = calendarIdList[i]
			var calendarEvents = calendars[calendarId]
			setCalendarData(calendarId, {
				"items": calendarEvents
			})
		}

		// Register calendars we didn't fetch so we can create events with them
		var calendarList = getCalendarList()
		for (var i = 0; i < calendarList.length; i++) {
			var calendar = calendarList[i]
			if (calendarIdList.indexOf(calendar.id) >= 0) {
				continue
			}
			setCalendarData(calendar.id, {
				"items": [],
			})
		}
	}

	onCalendarParsing: function(calendarId, data) {
		var calendar = getCalendar(calendarId)
		parseEventList(calendar, data.items)
	}

	function parseEvent(calendar, event) {
		// event.backgroundColor = calendar.backgroundColor
		event.canEdit = false
	}

	function parseEventList(calendar, eventList) {
		eventList.forEach(function(event) {
			parseEvent(calendar, event)
		})
	}

	//--- Create
	function createEvent(calendarId, date, text) {
		if (calendarId.indexOf('plasma_Events_') != 0) {
			logger.log('Could not create event with calendarId=', calendarId)
			return
		}
		var akonadiCalendarId = calendarId.substr('plasma_Events_'.length)
		if (isNaN(parseInt(akonadiCalendarId, 10))) {
			logger.log('Could not parse a proper akonadiCalendarId=', akonadiCalendarId, ' from calendarId=', calendarId)
			return
		}
		var dateString = Shared.dateString(date)

		// konsolekalendar --add --calendar 12 --summary "Summary" --date 2020-07-27 --time 22:00
		var cmd = [
			'konsolekalendar',
			'--add',
			'--calendar',
			akonadiCalendarId,
			'--date',
			dateString,
			'--summary',
			text,
		]
		executable.exec(cmd, function(cmd, exitCode, exitStatus, stdout, stderr){
			logger.debug('konsolekalendar.cmd', cmd)
			logger.debug('konsolekalendar.exitCode', exitCode)
			logger.debug('konsolekalendar.exitStatus', exitStatus)
			logger.debug('konsolekalendar.stdout', stdout)
			logger.debug('konsolekalendar.stderr', stderr)

			if (exitCode == 0) {
				// It takes a few secs for PIM Events to sync with the PlasmaCalendar API.
				// refresh calls deferredUpdate which is a 200ms delay which seems to work.
				refresh()
			} else {
				// Error
			}
		})
	}
}
