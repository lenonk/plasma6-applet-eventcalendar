import QtQuick 2.0
import org.kde.plasma.core as PlasmaCore

import "../lib"

CalendarManager {
	id: icalManager

	calendarManagerId: "ical"
	ExecUtil { id: executable }

	// property var eventsData: { "items": [] }

	property var calendarList: []

	function getCalendar(calendarId) {
		var list = calendarList || []
		for (var i = 0; i < list.length; i++) {
			var calendarData = list[i]
			if (calendarData.url == calendarId) {
				return calendarData
			}
		}
		return null
	}

	function formatDate(date) {
		return date.getFullYear() + '-' + (date.getMonth()+1) + '-' + date.getDate()
	}

	function fetchEvents(calendarData, startTime, endTime, callback) {
		logger.debug('ical.fetchEvents', calendarData.url)
		var scriptPath = executable.urlToLocalPath(Qt.resolvedUrl("../../scripts/icsjson.py"))
		// The array form quotes every token. "--url=" stops a leading "-" parsing as a flag.
		executable.exec([
			'python3', scriptPath,
			'--url=' + calendarData.url,
			'query', formatDate(startTime), formatDate(endTime),
		], function(cmd, exitCode, exitStatus, stdout, stderr) {
			if (exitCode) {
				logger.log('ical.stderr', stderr)
				return callback(stderr || ('icsjson.py exit code ' + exitCode))
			}
			try {
				var data = JSON.parse(stdout)
			} catch (e) {
				return callback('icsjson.py returned invalid JSON: ' + e)
			}
			callback(null, data)
		})
	}

	function fetchCalendar(calendarData) {
		icalManager.asyncRequests += 1
		var generation = icalManager.fetchGeneration
		fetchEvents(calendarData, dateMin, dateMax, function(err, data) {
			if (generation !== icalManager.fetchGeneration) return // Cleared by a newer fetchAll.
			if (err) {
				logger.log('ical.fetchCalendar.err', calendarData.url, err)
			} else {
				setCalendarData(calendarData.url, data)
			}
			icalManager.asyncRequestsDone += 1
		})
	}

	onFetchAllCalendars: {
		var list = calendarList || []
		for (var i = 0; i < list.length; i++) {
			var calendarData = list[i]
			if (calendarData && calendarData.url && calendarData.show !== false) {
				fetchCalendar(calendarData)
			}
		}
	}

	function parseCalendar(calendarId, data) {
		var calendar = getCalendar(calendarId)
		parseEventList(calendar, data.items)
	}

	function parseEvent(calendar, event) {
		event.backgroundColor = calendar.backgroundColor
		event.canEdit = false
	}

	function parseEventList(calendar, eventList) {
		eventList.forEach(function(event) {
			parseEvent(calendar, event)
		})
	}

	// onCalendarFetched: {
	// 	console.log(calendarId, data)
	// }

	// Component.onCompleted: {
	// 	var startTime = new Date(2017, 07-1, 01)
	// 	var endTime = new Date(2017, 07-1, 31)
	// 	dateMin = startTime
	// 	dateMax = endTime
	// 	fetchAllCalendars()
	// }
}
