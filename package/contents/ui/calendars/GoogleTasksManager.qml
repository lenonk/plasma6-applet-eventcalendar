import QtQuick 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import "../Shared.js" as Shared
import "../ErrorType.js" as ErrorType
import "../lib/Async.js" as Async
import "../lib/Requests.js" as Requests

// import "./GoogleCalendarTests.js" as GoogleCalendarTests


// Google Tasks API
// https://developers.google.com/tasks/v1/reference/tasks

// You can view Google Tasks with this URL:
// https://tasks.google.com/embed/?origin=https%3A%2F%2Fcalendar.google.com&fullWidth=1
// Note that it redirects to /embed/list/~default which you cannot bookmark, as it'll 404.

CalendarManager {
	id: googleTasksManager

	calendarManagerId: "GoogleTasks"

	property var session
	readonly property var tasklistIdList: session.cfg("tasklistIdList") ? session.cfg("tasklistIdList").split(',') : []

	onFetchAllCalendars: {
		fetchGoogleAccountData()
	}

	function fetchGoogleAccountData() {
		if (session.accessToken) {
			fetchGoogleAccountTasks(tasklistIdList)
		}
	}

	//--- Utils
	function cloneRawTask(task) {
		var validProperties = [
			'kind',
			'id',
			'etag',
			'title',
			'updated',
			'selfLink',
			'parent',
			'position',
			'notes',
			'status',
			'due',
			'completed',
			'deleted',
			'hidden',
			'links',
		]
		var data = {}
		for (var i = 0; i < validProperties.length; i++) {
			var key = validProperties[i]
			var value = task[key]
			if (typeof value !== 'undefined') {
				data[key] = value
			}
		}
		return data
	}

	//-------------------------
	// CalendarManager
	function getCalendarList() {
		if (session.accessToken && session.cfg("tasklistList")) {
			var tasklistList = JSON.parse(Qt.atob(session.cfg("tasklistList")))
			var calendarList = []
			for (var i = 0; i < tasklistList.length; i++) {
				var tasklist = tasklistList[i]
				calendarList.push({
					id: tasklist.id,
					summary: tasklist.title,
					backgroundColor: Kirigami.Theme.highlightColor.toString(),
					accessRole: 'owner',
					isTasklist: true,
				})
			}
			return calendarList
		} else {
			return []
		}
	}


	//-------------------------
	// Tasks
	function fetchGoogleAccountTasks(tasklistIdList) {
		googleTasksManager.asyncRequests += 1
		var generation = googleTasksManager.fetchGeneration
		function isStale() {
			if (generation === googleTasksManager.fetchGeneration) return false
			logger.debug('fetchGoogleAccountTasks: dropping stale response', generation)
			return true
		}
		session.checkAccessToken(function(tokenErr, tokenXhr) {
			if (isStale()) return
			if (tokenErr) {
				googleTasksManager.asyncRequestsDone += 1
				return handleTokenError(tokenErr, tokenXhr)
			}
			fetchGoogleAccountTasks_run(tasklistIdList, function(err, results) {
				if (isStale()) return
				fetchGoogleAccountTasks_done(results)
			})
		})
	}
	function fetchGoogleAccountTasks_run(tasklistIdList, callback) {
		logger.debug('fetchGoogleAccountTasks_run', tasklistIdList)

		var tasks = []
		for (var i = 0; i < tasklistIdList.length; i++) {
			var tasklistId = tasklistIdList[i]
			var task = fetchGoogleTasks.bind(this, tasklistId)
			tasks.push(task)
		}

		Async.parallel(tasks, callback)
	}
	function handleTokenError(err, xhr) {
		var e = session.describeTokenError(err, xhr)
		googleTasksManager.error(e.message, e.errorType)
	}
	function handleError(err, data, xhr) {
		var httpCode = xhr ? xhr.status : 0
		// A 2xx error body arrives as err; a non-2xx one as data (err is then "HTTP Error N").
		var body = (err && err.error) ? err : data
		var apiMsg = (body && body.error && body.error.message) || ((typeof err === 'string') ? err : '')
		var msg = httpCode === 0 ? i18n("Could not connect") : (apiMsg || i18n("Google Tasks request failed"))
		if (httpCode === 401) {
			googleTasksManager.error(i18n("HTTP Error %1: %2", httpCode, msg) + '\n' + i18n("Please log in to Google again."), ErrorType.ClientError)
			return
		}
		googleTasksManager.error(i18n("HTTP Error %1: %2", httpCode, msg),
			httpCode === 0 ? ErrorType.NetworkError : ErrorType.UnknownError)
	}
	function fetchGoogleAccountTasks_done(results) {
		// Store the tasklists that loaded, then report the ones that failed.
		var failed = []
		for (var i = 0; i < results.length; i++) {
			if (results[i].error) {
				failed.push(results[i])
				continue
			}
			var eventList = parseTasklistAsEvents(results[i].data)
			setCalendarData(results[i].tasklistId, eventList)
		}
		googleTasksManager.asyncRequestsDone += 1
		for (var j = 0; j < failed.length; j++) {
			var errObj = failed[j].error
			logger.debug('fetchGoogleAccountTasks_err', failed[j].tasklistId, errObj.err, errObj.data, errObj.xhr)
			handleError(errObj.err, errObj.data, errObj.xhr)
		}
	}

	function sortTasklist(tasklist) {
		tasklist.sort(function(a,b) {
			if (typeof a.position !== 'undefined') {
				if (typeof b.position !== 'undefined') {
					var ap = a.position
					var bp = b.position
					if (ap == bp) {
						return 0
					} else if (ap < bp) {
						return -1
					} else { // ap > bp
						return 1
					}
				} else {
					return 1
				}
			} else {
				if (typeof b.position !== 'undefined') {
					return -1
				} else {
					0
				}
			}
		})

		//--- Debug
		// for (var i = 0; i < tasklist.length; i++) {
		// 	var taskData = tasklist[i]
		// 	logger.debug('task', i, taskData.position, taskData.title)
		// }
	}

	function parseTasklistAsEvents(tasklistData) {
		var eventList = []
		var items = tasklistData.items || [] // Omitted by the API for an empty list
		for (var i = 0; i < items.length; i++) {
			var taskData = items[i]
			// logger.debugJSON('tasklistData', i, taskData)
			var eventData = parseTaskAsEventData(taskData)
			// logger.debugJSON('tasklistData', i, eventData)
			eventList.push(eventData)
		}

		// Note that AgendaModel will sort again in AgendaModel.parseGCalEvents,
		// which ruins this sorting.
		sortTasklist(eventList)

		return {
			items: eventList,
		}
	}

	function parseTaskAsEventData(taskData) {
		// Don't bother creating a new object.
		var eventData = taskData

		eventData.summary = taskData.title
		eventData.canEdit = true

		var editTasksUrl = 'https://tasks.google.com/embed/?origin=' + encodeURIComponent('https://calendar.google.com') + '&fullWidth=1'
		eventData.htmlLink = editTasksUrl

		eventData.isCompleted = taskData.status == "completed"

		if (taskData.completed) {
			var completedAt = new Date(taskData.completed)
			var startDateTime = new Date(completedAt.getFullYear(), completedAt.getMonth(), completedAt.getDate())
		} else if (taskData.due) {
			// Note: In the Google Tasks API docs:
			// The due date only records date information; the time portion of the timestamp is discarded when setting the due date.
			// It isn't possible to read or write the time that a task is due via the API.
			// due is UTC midnight of the due day, take the date as-is
			eventData.dueDate = taskData.due.substr(0, 10)
			eventData.dueDateTime = new Date(eventData.dueDate + ' 00:00:00')
			// All day event, due at end of day.
			eventData.dueEndOfDay = taskData.due.indexOf('T00:00:00.000Z') !== -1
			if (eventData.dueEndOfDay) {
				var dueEndTime = new Date(eventData.dueDateTime)
				dueEndTime.setDate(dueEndTime.getDate() + 1)
				eventData.dueEndTime = dueEndTime
			} else {
				eventData.dueEndTime = eventData.dueDateTime
			}
			var startDateTime = new Date(eventData.dueDateTime)
		} else {
			var today = new Date()
			var startDateTime = new Date(today.getFullYear(), today.getMonth(), today.getDate())
		}
		var endDateTime = new Date(startDateTime)
		endDateTime.setDate(endDateTime.getDate() + 1)
		// startDateTime is local midnight, so format it in local time.
		eventData.start = {
			date: Shared.localeDateString(startDateTime),
		}
		eventData.end = {
			date: Shared.localeDateString(endDateTime),
		}

		if (taskData.parent) {
			// TODO: This is a subtask
		}

		return eventData
	}

	function fetchGoogleTasks(tasklistId, callback) {
		logger.debug('fetchGoogleTasks', tasklistId)
		fetchGCalTasks({
			tasklistId: tasklistId,
			// start: googleTasksManager.dateMin.toISOString(),
			// end: googleTasksManager.dateMax.toISOString(),
			accessToken: session.accessToken,
		}, function(err, data, xhr) {
			if (err) {
				logger.logJSON('onErrorFetchingTasks: ', err)
				// Don't fail the whole Async.parallel batch for one tasklist.
				return callback(null, {
					tasklistId: tasklistId,
					error: {
						err: err,
						data: data,
						xhr: xhr,
					},
				})
			}

			return callback(null, {
				tasklistId: tasklistId,
				data: data,
			})
		})
	}

	function fetchGCalTasks(args, callback) {
		logger.debug('fetchGCalTasks', args.tasklistId)

		// return GoogleCalendarTests.testInvalidCredentials(callback)
		// return GoogleCalendarTests.testDailyLimitExceeded(callback)
		// return GoogleCalendarTests.testBackendError(callback)

		var onResponse = fetchGCalTasksPageResponse.bind(this, args, callback, null)
		fetchGCalTasksPage(args, onResponse)
	}

	function fetchGCalTasksPageResponse(args, finishedCallback, allData, err, data, xhr) {
		logger.debug('fetchGCalTasksPageResponse', args, finishedCallback, allData, err, data, xhr)
		if (err) {
			return finishedCallback(err, data, xhr)
		}
		if (allData) {
			data.items = (allData.items || []).concat(data.items || [])
			delete allData.items
			delete allData
		}
		allData = data
		
		if (allData.nextPageToken) {
			logger.debug('fetchGCalTasksPageResponse.nextPageToken', allData.nextPageToken)
			logger.debug('fetchGCalTasksPageResponse.nextPageToken', 'allData.items.length', allData.items && allData.items.length)
			args.pageToken = allData.nextPageToken
			var onResponse = fetchGCalTasksPageResponse.bind(this, args, finishedCallback, allData)
			fetchGCalTasksPage(args, onResponse)
		} else {
			logger.debug('fetchGCalTasksPageResponse.finished', 'allData.items.length', allData.items && allData.items.length)
			finishedCallback(err, allData, xhr)
		}
	}

	function fetchGCalTasksPage(args, pageCallback) {
		logger.debug('fetchGCalTasksPage', args.tasklistId)
		var url = 'https://www.googleapis.com/tasks/v1'
		url += '/lists/'
		url += encodeURIComponent(args.tasklistId)
		url += '/tasks'
		if (plasmoid.configuration.googleTasksHideCompleted) {
			url += '?showCompleted=false'
			url += '&showHidden=false'
		} else {
			url += '?showCompleted=true'
			url += '&showHidden=true'
		}
		// url += '&dueMin=' + encodeURIComponent(args.start)
		// url += '&dueMax=' + encodeURIComponent(args.end)
		if (args.pageToken) {
			url += '&pageToken=' + encodeURIComponent(args.pageToken)
		}
		Requests.getJSON({
			url: url,
			headers: {
				"Authorization": "Bearer " + args.accessToken,
			}
		}, function(err, data, xhr) {
			logger.debug('fetchGCalTasksPage.response', args.tasklistId, err, data, xhr.status)
			if (!err && data && data.error) {
				return pageCallback(data, null, xhr)
			}
			// logger.debugJSON('fetchGCalTasksPage.response', args.tasklistId, data)
			pageCallback(err, data, xhr)
		})
	}


	//--- Create / POST
	function createEvent(calendarId, date, text) {
		if (session.accessToken) {
			var eventText = text

			// Without a due date Google Calendar doesn't show the task at all,
			// so use the agenda day it was added on. The API keeps only the date.
			var due = date ? Shared.localeDateString(date) + 'T00:00:00.000Z' : null

			session.checkAccessToken(function(tokenErr, tokenXhr) {
				if (tokenErr) return handleTokenError(tokenErr, tokenXhr)
				createEvent_run(calendarId, eventText, due, function(err, data, xhr) {
					if (err) {
						createEvent_err(err, data, xhr)
					} else {
						createEvent_done(calendarId, data)
					}
				})
			})
		} else {
			session.transactionError('attempting to "create an event" without an access token set')
		}
	}
	function createEvent_run(calendarId, eventText, due, callback) {
		logger.debugJSON(calendarManagerId, 'createEvent_run', calendarId, eventText, due)
		createGoogleTask({
			accessToken: session.accessToken,
			tasklistId: calendarId,
			title: eventText,
			due: due,
		}, callback)
	}
	function createEvent_done(calendarId, data) {
		logger.debugJSON(calendarManagerId, 'createEvent_done', calendarId, data)
		if (googleTasksManager.tasklistIdList.indexOf(calendarId) >= 0 && getCalendarItems(calendarId)) {
			var eventData = parseTaskAsEventData(data)
			parseSingleEvent(calendarId, eventData)
			addEvent(calendarId, eventData)
			eventCreated(calendarId, eventData)
		}
	}
	function createEvent_err(err, data, xhr) {
		logger.log(calendarManagerId, 'createEvent_err', err, data, xhr)
		return handleError(err, data, xhr)
	}

	function createGoogleTask(args, callback) {
		// https://www.googleapis.com/tasks/v1/lists/tasklistId/tasks
		var url = 'https://www.googleapis.com/tasks/v1'
		url += '/lists/'
		url += encodeURIComponent(args.tasklistId)
		url += '/tasks'
		var taskData = {
			title: args.title,
			// notes: args.notes,
		}
		if (args.due) {
			taskData.due = args.due
		}
		Requests.postJSON({
			url: url,
			headers: {
				"Authorization": "Bearer " + args.accessToken,
			},
			data: taskData,
		}, function(err, data, xhr) {
			console.log('createGoogleTask.response', err, data, xhr.status)
			if (!err && data && data.error) {
				return callback(data, null, xhr)
			}
			callback(err, data, xhr)
		})
	}


	//--- Delete Task
	function deleteEvent(calendarId, eventId) {
		logger.log(calendarManagerId, 'deleteEvent', calendarId, eventId)
		if (session.accessToken) {
			var event = getEvent(calendarId, eventId)
			if (!event) {
				session.transactionError('attempting to "delete an event" for an event that doesn\'t exist')
				return
			}

			session.checkAccessToken(function(tokenErr, tokenXhr) {
				if (tokenErr) return handleTokenError(tokenErr, tokenXhr)
				deleteEvent_run(calendarId, eventId, function(err, data, xhr) {
					if (err) {
						deleteEvent_err(err, data, xhr)
					} else {
						deleteEvent_done(calendarId, eventId, data)
					}
				})
			})
		} else {
			session.transactionError('attempting to "delete an event" without an access token set')
		}
	}
	function deleteEvent_run(calendarId, eventId, callback) {
		logger.debugJSON(calendarManagerId, 'deleteEvent_run', calendarId, eventId)

		deleteGoogleTask({
			accessToken: session.accessToken,
			tasklistId: calendarId,
			taskId: eventId,
		}, callback)
	}
	function deleteEvent_done(calendarId, eventId, data) {
		logger.debugJSON(calendarManagerId, 'deleteEvent_done', calendarId, eventId, data)

		// Note: No data is returned on success
		var event = getEvent(calendarId, eventId)
		if (event) {
			removeEvent(calendarId, eventId)
			eventDeleted(calendarId, eventId, event)
		}
	}
	function deleteEvent_err(err, data, xhr) {
		logger.log(calendarManagerId, 'deleteEvent_err', err, data, xhr)
		return handleError(err, data, xhr)
	}

	function deleteGoogleTask(args, callback) {
		// DELETE https://www.googleapis.com/tasks/v1/lists/tasklistId/tasks/taskId
		// Note: Success means a response of xhr.status == 204 (No Content)
		var url = 'https://www.googleapis.com/tasks/v1'
		url += '/lists/'
		url += encodeURIComponent(args.tasklistId)
		url += '/tasks/'
		url += encodeURIComponent(args.taskId)
		Requests.postJSON({
			method: 'DELETE',
			url: url,
			headers: {
				"Authorization": "Bearer " + args.accessToken,
			},
		}, function(err, data, xhr) {
			logger.debug('deleteGoogleTask.response', err, data, xhr.status)
			if (!err && data && data.error) {
				return callback(data, null, xhr)
			}
			callback(err, data, xhr)
		})
	}

	//--- Update Task
	function setEventProperty(calendarId, eventId, key, value) {
		logger.log(calendarManagerId, 'setEventProperty', calendarId, eventId, key, value)
		var args = {}
		args[key] = value
		setEventProperties(calendarId, eventId, args)
	}

	function setEventProperties(calendarId, eventId, args) {
		logger.logJSON(calendarManagerId, 'setEventProperties', calendarId, eventId, args)
		if (session.accessToken) {
			var event = getEvent(calendarId, eventId)
			if (!event) {
				session.transactionError('attempting to "set an event property" for an event that doesn\'t exist')
				return
			}

			session.checkAccessToken(function(tokenErr, tokenXhr) {
				if (tokenErr) return handleTokenError(tokenErr, tokenXhr)
				setEventProperties_run(calendarId, eventId, event, args, function(err, data, xhr) {
					if (err) {
						setEventProperties_err(err, data, xhr)
					} else {
						setEventProperties_done(calendarId, eventId, event, data)
					}
				})
			})
		} else {
			session.transactionError('attempting to "set an event property" without an access token set')
		}
	}
	function setEventProperties_run(calendarId, eventId, event, args, callback) {
		logger.debugJSON(calendarManagerId, 'setEventProperties_run', calendarId, eventId, event, args)
		
		// Merge assigned values into a cloned object
		var data = cloneRawTask(event)
		Shared.merge(data, args)
		logger.debugJSON(calendarManagerId, 'setEventProperties', 'sent', data)

		updateGoogleTask({
			accessToken: session.accessToken,
			tasklistId: calendarId,
			taskId: eventId,
			data: data,
		}, callback)
	}
	function setEventProperties_done(calendarId, eventId, event, data) {
		logger.debugJSON(calendarManagerId, 'setEventProperties_done', calendarId, data)

		// Merge serialized values
		var eventData = parseTaskAsEventData(data)

		// Completed tasks aren't fetched with this option, drop it now instead
		// of moving it to the completion day until the next refresh.
		if (eventData.isCompleted && plasmoid.configuration.googleTasksHideCompleted) {
			removeEvent(calendarId, eventId)
			return
		}

		Shared.merge(event, eventData)
		Shared.removeMissingKeys(event, eventData)

		parseSingleEvent(calendarId, event)
		eventUpdated(calendarId, eventId, event)
	}
	function setEventProperties_err(err, data, xhr) {
		logger.log(calendarManagerId, 'setEventProperties_err', err, data, xhr)
		return handleError(err, data, xhr)
	}

	function updateGoogleTask(args, callback) {
		// PUT https://www.googleapis.com/tasks/v1/lists/tasklistId/tasks/taskId
		var url = 'https://www.googleapis.com/tasks/v1'
		url += '/lists/'
		url += encodeURIComponent(args.tasklistId)
		url += '/tasks/'
		url += encodeURIComponent(args.taskId)
		Requests.postJSON({
			method: 'PUT',
			url: url,
			headers: {
				"Authorization": "Bearer " + args.accessToken,
			},
			data: args.data,
		}, function(err, data, xhr) {
			logger.debug('updateGoogleTask.response', err, data, xhr.status)
			if (!err && data && data.error) {
				return callback(data, null, xhr)
			}
			callback(err, data, xhr)
		})
	}
}
