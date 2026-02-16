import QtQuick 2.0
import "./ErrorType.js" as ErrorType
import "./weather/WeatherApi.js" as WeatherApi

	Item {
		// Filled by `main.qml` when the popup component is instantiated.
		property var popup: null

		//--- Weather
		property var dailyWeatherData: { "list": [] }
		property var hourlyWeatherData: { "list": [] }
		property var currentWeatherData: null
		// Separate timestamps since we can fetch daily while the popup is closed,
		// but only fetch hourly once the popup (meteogram) exists.
		property var lastDailyForecastAt: null
		property var lastHourlyForecastAt: null
		property var lastForecastErr: null
		property bool pendingDailyUpdate: false
		property bool pendingHourlyUpdate: false


	//--- Main
	Component.onCompleted: {
		pollTimer.start()
	}


	//--- Update
	Timer {
		id: pollTimer
		
		repeat: true
		triggeredOnStart: true
		interval: plasmoid.configuration.eventsPollInterval * 60000
		onTriggered: logic.update()
	}

	function update() {
		logger.debug('update')
		logic.updateData()
	}

	function updateData() {
		logger.debug('updateData')
		logic.updateEvents()
		logic.updateWeather()
	}



	//--- Events
	function updateEvents() {
		updateEventsTimer.restart()
	}
	Timer {
		id: updateEventsTimer
		interval: 200
		onTriggered: logic.deferredUpdateEvents()
	}
	function deferredUpdateEvents() {
		var range = agendaModel.getDateRange(agendaModel.currentMonth)
		// console.log('   first', monthView.firstDisplayedDate())
		// console.log('    last', monthView.lastDisplayedDate())

		agendaModel.visibleDateMin = range.min
		agendaModel.visibleDateMax = range.max
		eventModel.fetchAll(range.min, range.max)
	}


		//--- Weather
		function updateWeather(force) {
			if (WeatherApi.weatherIsSetup(plasmoid.configuration)) {
				function shouldUpdateAt(lastAt) {
					if (!lastAt) return true
					var now = new Date()
					var currentHour = now.getHours()
					var lastUpdateHour = new Date(lastAt).getHours()
					var beenOverAnHour = now.valueOf() - lastAt >= 60 * 60 * 1000
					return lastUpdateHour != currentHour || beenOverAnHour
				}

				// Fetch hourly data as long as the meteogram is enabled.
				// This ensures the graph is populated immediately when the popup is first opened
				// (the popup may be instantiated lazily, so relying on expansion signals is flaky).
				var wantHourly = plasmoid.configuration.widgetShowMeteogram
				var haveDaily = dailyWeatherData && dailyWeatherData.list && dailyWeatherData.list.length > 0
				var haveHourly = hourlyWeatherData && hourlyWeatherData.list && hourlyWeatherData.list.length > 0

				pendingDailyUpdate = !!(force || shouldUpdateAt(lastDailyForecastAt) || !haveDaily)
				pendingHourlyUpdate = !!(wantHourly && (force || shouldUpdateAt(lastHourlyForecastAt) || !haveHourly))

				if (pendingDailyUpdate || pendingHourlyUpdate) {
					updateWeatherTimer.restart()
				}
			}
		}
		Timer {
			id: updateWeatherTimer
			interval: 100
			onTriggered: logic.deferredUpdateWeather()
		}
		function deferredUpdateWeather() {
			var doDaily = pendingDailyUpdate
			var doHourly = pendingHourlyUpdate
			pendingDailyUpdate = false
			pendingHourlyUpdate = false

			if (doDaily) {
				logic.updateDailyWeather()
			}
			if (doHourly) {
				logic.updateHourlyWeather()
			}
		}

		function resetWeatherData() {
			logic.dailyWeatherData = { "list": [] }
			logic.hourlyWeatherData = { "list": [] }
			logic.currentWeatherData = null
			logic.lastDailyForecastAt = null
			logic.lastHourlyForecastAt = null
			logic.lastForecastErr = null
		}

	function resetWeatherAndUpdate() {
		logic.resetWeatherData()
		logic.updateWeather(true)
	}

		function handleWeatherError(funcName, err, data, xhr) {
			logger.log(funcName + '.err', err, xhr && xhr.status, data)
			var nowMs = Date.now()
			var isDaily = funcName.indexOf('Daily') >= 0
			var isHourly = funcName.indexOf('Hourly') >= 0
			if (xhr && xhr.status === 0) { // Error making connection
				var msg = i18n("Could not connect")
				var errorMessage = i18n("HTTP Error %1: %2", xhr.status, msg)
				errorMessage += '\n' + i18n("Will try again soon.")
				logic.lastForecastErr = errorMessage
			} else if (xhr && xhr.status == 429) {
				// If there's an error, don't bother the API for another hour.
				if (isDaily) logic.lastDailyForecastAt = nowMs
				if (isHourly) logic.lastHourlyForecastAt = nowMs
				var msg = i18n("Weather API limit reached")
				var errorMessage = i18n("HTTP Error %1: %2", xhr.status, msg)
				errorMessage += '\n' + i18n("Will try again soon.")
				logic.lastForecastErr = errorMessage
			} else {
				// If there's an error, don't bother the API for another hour.
				if (isDaily) logic.lastDailyForecastAt = nowMs
				if (isHourly) logic.lastHourlyForecastAt = nowMs
				logic.lastForecastErr = err
			}
		}

		function updateDailyWeather() {
			logger.debug('updateDailyWeather', lastDailyForecastAt, Date.now())
			WeatherApi.updateDailyWeather(plasmoid.configuration, function(err, data, xhr) {
				if (err) return handleWeatherError('updateDailyWeather', err, data, xhr)
				logger.debugJSON('updateDailyWeather.response', data)

				logic.lastDailyForecastAt = Date.now()
				logic.lastForecastErr = null
				logic.dailyWeatherData = data
				if (popup) {
					popup.updateUI()
				}
		})
	}

			function updateHourlyWeather() {
				logger.debug('updateHourlyWeather', lastHourlyForecastAt, Date.now())
				WeatherApi.updateHourlyWeather(plasmoid.configuration, function(err, data, xhr) {
					if (err) return handleWeatherError('updateHourlyWeather', err, data, xhr)
					logger.debugJSON('updateHourlyWeather.response', data)

					logic.lastHourlyForecastAt = Date.now()
					logic.lastForecastErr = null
					logic.hourlyWeatherData = data
					logic.currentWeatherData = (data && data.current) ? data.current : ((data && data.list && data.list.length) ? data.list[0] : null)
					if (popup) {
					popup.updateMeteogram()
				}
			})
		}

	//---
	Connections {
		target: plasmoid.configuration

		//--- Events
		function onAccessTokenChanged() { logic.updateEvents() }
		function onCalendarIdListChanged() { logic.updateEvents() }
		function onEnabledCalendarPluginsChanged() { logic.updateEvents() }
		function onTasklistIdListChanged() { logic.updateEvents() }
		function onGoogleEventClickActionChanged() { logic.updateEvents() }

			//--- Weather
			function onWeatherServiceChanged() { logic.resetWeatherAndUpdate() }
			function onOpenMeteoLocationNameChanged() { logic.resetWeatherAndUpdate() }
			function onOpenMeteoLatitudeChanged() { logic.resetWeatherAndUpdate() }
			function onOpenMeteoLongitudeChanged() { logic.resetWeatherAndUpdate() }
			function onWeatherCanadaCityIdChanged() { logic.resetWeatherAndUpdate() }
			function onWeatherUnitsChanged() { logic.updateWeather(true) }
		function onWidgetShowMeteogramChanged() {
			if (plasmoid.configuration.widgetShowMeteogram) {
				logic.updateHourlyWeather()
			}
		}

		//--- UI
		function onAgendaBreakupMultiDayEventsChanged() { popup.updateUI() }
		function onMeteogramHoursChanged() { popup.updateMeteogram() }
	}

	//---
	Connections {
		target: appletConfig
		function onClock24hChanged() { popup.updateUI() }
	}

	//---
	property int currentErrorType: ErrorType.UnknownError
	property string currentErrorMessage: {
		if (plasmoid.configuration.accessToken && plasmoid.configuration.latestClientId != plasmoid.configuration.sessionClientId) {
			return i18n("Widget has been updated. Please logout and login to Google Calendar again.")
		} else if (!plasmoid.configuration.accessToken && plasmoid.configuration.access_token) {
			return i18n("Logged out of Google. Please login again.")
		} else {
			return ""
		}
	}
	function clearError() {
		currentErrorType = ErrorType.NoError
		if (popup) popup.clearError()
	}
	Connections {
		target: eventModel
		function onError(errorType, msg) {
			logic.currentErrorMessage = msg
			logic.currentErrorType = errorType
			if (popup) popup.showError(logic.currentErrorMessage)
		}
	}

	//---
	Connections {
		target: eventModel
		function onCalendarFetched(calendarId, data) {
			logger.debug('onCalendarFetched', calendarId)
			// logger.debug('onCalendarFetched', calendarId, JSON.stringify(data, null, '\t'))
			if (popup) popup.deferredUpdateUI()
		}
		function onAllDataFetched() {
			logger.debug('onAllDataFetched')
			if (popup) popup.deferredUpdateUI()
		}
		function onEventCreated(calendarId, data) {
			logger.logJSON('onEventCreated', calendarId, data)
			if (popup) popup.deferredUpdateUI()
		}
		function onEventUpdated(calendarId, eventId, data) {
			logger.logJSON('onEventUpdated', calendarId, eventId, data)
			if (popup) popup.deferredUpdateUI()
		}
		function onEventDeleted(calendarId, eventId, data) {
			logger.logJSON('onEventDeleted', calendarId, eventId, data)
			if (popup) popup.deferredUpdateUI()
		}
	}

	//---
	Connections {
		target: networkMonitor
		function onIsConnectedChanged() {
			if (networkMonitor.isConnected) {
				if (logic.currentErrorType == ErrorType.NetworkError) {
					logic.clearError()
				}
				logic.update()
			}
		}
	}
}
