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
		property int weatherRetryAttempt: 0
		property string pendingWeatherNetworkError: ""
		property int eventRetryAttempt: 0
		property string pendingEventNetworkError: ""
		property double lastPollTriggeredAt: 0


	//--- Main
	Component.onCompleted: {
		pollTimer.start()
	}


	//--- Update
	Timer {
		id: pollTimer
		
		repeat: true
		triggeredOnStart: true
		interval: Math.max(60000, Number(plasmoid.configuration.eventsPollInterval || 20) * 60000)
		onTriggered: {
			var now = Date.now()
			var resumedAfterTimerWasDue = lastPollTriggeredAt > 0
				&& now - lastPollTriggeredAt > pollTimer.interval + 5000
			lastPollTriggeredAt = now
			if (resumedAfterTimerWasDue) {
				// An overdue QML timer fires immediately after resume, before
				// NetworkManager has rebuilt Wi-Fi, routing and DNS. Give it time.
				resumeUpdateTimer.restart()
			} else {
				logic.update()
			}
		}
	}
	Timer {
		id: resumeUpdateTimer
		interval: 15000
		repeat: false
		onTriggered: logic.updateData()
	}
	Timer {
		id: networkOnlineTimer
		interval: 2000
		repeat: false
		onTriggered: {
			resumeUpdateTimer.stop()
			logic.updateData()
		}
	}

	function update() {
		logger.debug('update')
		logic.updateData()
	}

	function updateData() {
		logger.debug('updateData')
		// Plasma can instantiate the applet before NetworkManager has finished
		// reconnecting (for example immediately after login or a shell restart).
		// Avoid firing requests that are guaranteed to fail with HTTP status 0;
		// the network-status connection below refreshes everything once online.
		if (!networkMonitor.isConnected) {
			logger.debug('updateData skipped: network is not connected')
			return
		}
		logic.updateEvents()
		logic.updateWeather()
	}

	//--- Events
	function updateEvents() {
		if (!networkMonitor.isConnected) {
			logic.scheduleEventRetry()
			return
		}
		updateEventsTimer.restart()
	}
	Timer {
		id: updateEventsTimer
		interval: 200
		onTriggered: logic.deferredUpdateEvents()
	}
	Timer {
		id: eventRetryTimer
		repeat: false
		onTriggered: {
			if (networkMonitor.isConnected) {
				logic.updateEvents()
			} else {
				logic.scheduleEventRetry()
			}
		}
	}
	Timer {
		id: eventNetworkErrorDisplayTimer
		interval: 60000
		repeat: false
		onTriggered: {
			if (pendingEventNetworkError) {
				logic.currentErrorMessage = pendingEventNetworkError
				logic.currentErrorType = ErrorType.NetworkError
				if (popup) popup.showError(logic.currentErrorMessage)
			}
		}
	}
	function scheduleEventRetry() {
		if (eventRetryTimer.running) {
			return
		}
		var delays = [10000, 30000, 60000, 120000, 300000]
		var delayIndex = Math.min(eventRetryAttempt, delays.length - 1)
		eventRetryTimer.interval = delays[delayIndex]
		eventRetryAttempt = Math.min(eventRetryAttempt + 1, delays.length - 1)
		eventRetryTimer.start()
	}
	function clearEventNetworkRecovery() {
		pendingEventNetworkError = ""
		eventRetryAttempt = 0
		eventRetryTimer.stop()
		eventNetworkErrorDisplayTimer.stop()
		if (logic.currentErrorType == ErrorType.NetworkError) {
			logic.clearError()
		}
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
			if (!networkMonitor.isConnected) {
				logger.debug('updateWeather skipped: network is not connected')
				return
			}
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
		Timer {
			id: weatherRetryTimer
			repeat: false
			onTriggered: {
				if (networkMonitor.isConnected) {
					logic.updateWeather(true)
				} else {
					logic.scheduleWeatherRetry()
				}
			}
		}
		Timer {
			id: weatherNetworkErrorDisplayTimer
			interval: 60000
			repeat: false
			onTriggered: {
				if (pendingWeatherNetworkError) {
					logic.lastForecastErr = pendingWeatherNetworkError
				}
			}
		}
		function scheduleWeatherRetry() {
			// Daily and hourly requests normally fail together. Let the first one
			// schedule the shared retry instead of doubling the backoff.
			if (weatherRetryTimer.running) {
				return
			}
			var delays = [10000, 30000, 60000, 120000, 300000]
			var delayIndex = Math.min(weatherRetryAttempt, delays.length - 1)
			weatherRetryTimer.interval = delays[delayIndex]
			weatherRetryAttempt = Math.min(weatherRetryAttempt + 1, delays.length - 1)
			weatherRetryTimer.start()
			logger.debug('Weather retry scheduled in ms', weatherRetryTimer.interval)
		}
		function clearWeatherRetry() {
			pendingWeatherNetworkError = ""
			weatherRetryAttempt = 0
			weatherRetryTimer.stop()
			weatherNetworkErrorDisplayTimer.stop()
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
			logic.clearWeatherRetry()
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

		function localizeWeatherText(text) {
			switch (text) {
			case "Clear": return i18n("Clear")
			case "Mostly Clear": return i18n("Mostly Clear")
			case "Partly Cloudy": return i18n("Partly Cloudy")
			case "Overcast": return i18n("Overcast")
			case "Fog": return i18n("Fog")
			case "Drizzle": return i18n("Drizzle")
			case "Freezing Drizzle": return i18n("Freezing Drizzle")
			case "Rain": return i18n("Rain")
			case "Freezing Rain": return i18n("Freezing Rain")
			case "Snow": return i18n("Snow")
			case "Showers": return i18n("Showers")
			case "Snow Showers": return i18n("Snow Showers")
			case "Thunderstorm": return i18n("Thunderstorm")
			default: return text
			}
		}

		function localizeWeatherDescription(description) {
			switch (description) {
			case "Clear sky": return i18n("Clear sky")
			case "Mainly clear": return i18n("Mainly clear")
			case "Partly cloudy": return i18n("Partly cloudy")
			case "Overcast": return i18n("Overcast")
			case "Fog": return i18n("Fog")
			case "Depositing rime fog": return i18n("Depositing rime fog")
			case "Light drizzle": return i18n("Light drizzle")
			case "Moderate drizzle": return i18n("Moderate drizzle")
			case "Dense drizzle": return i18n("Dense drizzle")
			case "Light freezing drizzle": return i18n("Light freezing drizzle")
			case "Dense freezing drizzle": return i18n("Dense freezing drizzle")
			case "Slight rain": return i18n("Slight rain")
			case "Moderate rain": return i18n("Moderate rain")
			case "Heavy rain": return i18n("Heavy rain")
			case "Light freezing rain": return i18n("Light freezing rain")
			case "Heavy freezing rain": return i18n("Heavy freezing rain")
			case "Slight snow fall": return i18n("Slight snow fall")
			case "Moderate snow fall": return i18n("Moderate snow fall")
			case "Heavy snow fall": return i18n("Heavy snow fall")
			case "Snow grains": return i18n("Snow grains")
			case "Slight rain showers": return i18n("Slight rain showers")
			case "Moderate rain showers": return i18n("Moderate rain showers")
			case "Violent rain showers": return i18n("Violent rain showers")
			case "Slight snow showers": return i18n("Slight snow showers")
			case "Heavy snow showers": return i18n("Heavy snow showers")
			case "Thunderstorm": return i18n("Thunderstorm")
			case "Thunderstorm with slight hail": return i18n("Thunderstorm with slight hail")
			case "Thunderstorm with heavy hail": return i18n("Thunderstorm with heavy hail")
			default: return description
			}
		}

		function localizeWeatherError(err) {
			if (err === "Open-Meteo latitude/longitude not set") {
				return i18n("Open-Meteo latitude/longitude not set")
			}
			if (err === "Weather configuration not setup") {
				return i18n("Weather configuration not setup")
			}
			return err
		}

		function localizeWeatherItem(item) {
			if (!item || typeof item !== "object") {
				return item
			}
			var out = Object.assign({}, item)
			if (typeof out.text === "string") {
				out.text = localizeWeatherText(out.text)
			}
			if (typeof out.description === "string") {
				out.description = localizeWeatherDescription(out.description)
			}
			return out
		}

		function localizeWeatherData(data) {
			if (!data || typeof data !== "object") {
				return data
			}
			var out = Object.assign({}, data)
			if (Array.isArray(data.list)) {
				out.list = data.list.map(localizeWeatherItem)
			}
			if (data.current && typeof data.current === "object") {
				out.current = localizeWeatherItem(data.current)
			}
			return out
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
				logic.pendingWeatherNetworkError = errorMessage
				if (!weatherNetworkErrorDisplayTimer.running) {
					weatherNetworkErrorDisplayTimer.start()
				}
				logic.scheduleWeatherRetry()
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
					logic.lastForecastErr = localizeWeatherError(err)
				}
			}

		function updateDailyWeather() {
			logger.debug('updateDailyWeather', lastDailyForecastAt, Date.now())
				WeatherApi.updateDailyWeather(plasmoid.configuration, function(err, data, xhr) {
					if (err) return handleWeatherError('updateDailyWeather', err, data, xhr)
					logger.debugJSON('updateDailyWeather.response', data)
					data = localizeWeatherData(data)

					logic.lastDailyForecastAt = Date.now()
					logic.clearWeatherRetry()
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
						data = localizeWeatherData(data)

						logic.lastHourlyForecastAt = Date.now()
						logic.clearWeatherRetry()
						logic.lastForecastErr = null
						logic.hourlyWeatherData = data
						logic.currentWeatherData = (data && data.current) ? data.current : ((data && data.list && data.list.length) ? data.list[0] : null)
						if (plasmoid.configuration.debugging) {
							var first = (data && data.list && data.list.length) ? data.list[0] : null
							var firstIso = (first && first.dt) ? (new Date(Number(first.dt) * 1000)).toString() : "none"
							var currentIso = (logic.currentWeatherData && logic.currentWeatherData.dt)
								? (new Date(Number(logic.currentWeatherData.dt) * 1000)).toString()
								: "none"
							console.log("[eventcalendar] hourly parsed first=", firstIso,
								"current=", currentIso,
								"first_dt=", first ? first.dt : "none",
								"current_dt=", logic.currentWeatherData ? logic.currentWeatherData.dt : "none")
						}
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
		function onAgendaBreakupMultiDayEventsChanged() { if (popup) popup.updateUI() }
		function onMeteogramHoursChanged() { if (popup) popup.updateMeteogram() }
	}

	//---
	Connections {
		target: appletConfig
		function onClock24hChanged() { if (popup) popup.updateUI() }
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
		currentErrorMessage = ""
		currentErrorType = ErrorType.NoError
		if (popup) popup.clearError()
	}
	Connections {
		target: eventModel
		function onError(msg, errorType) {
			if (errorType == ErrorType.NetworkError) {
				logic.pendingEventNetworkError = msg
				logic.scheduleEventRetry()
				if (!eventNetworkErrorDisplayTimer.running) {
					eventNetworkErrorDisplayTimer.start()
				}
				return
			}
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
			logic.clearEventNetworkRecovery()
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
			logger.debug('NetworkMonitor.isConnected changed', networkMonitor.isConnected)
			if (networkMonitor.isConnected) {
				// NetworkManager can announce Full just before DNS is usable. A
				// short settle delay avoids one final status-0 request on resume.
				networkOnlineTimer.restart()
			} else {
				networkOnlineTimer.stop()
			}
		}
	}
}
