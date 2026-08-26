import QtQuick 2.0

import "../lib/Requests.js" as Requests

QtObject {
	id: googleApiSession

	readonly property string accessToken: plasmoid.configuration.accessToken
	property bool refreshInProgress: false
	property var refreshWaiters: []

	//--- Refresh Credentials
	function checkAccessToken(callback) {
		logger.debug('checkAccessToken')
		if (plasmoid.configuration.accessTokenExpiresAt < Date.now() + 5000) {
			updateAccessToken(callback)
		} else {
			callback(null)
		}
	}

	function updateAccessToken(callback) {
		refreshWaiters.push(callback)
		if (refreshInProgress) return
		refreshInProgress = true
		function finishRefresh(err) {
			var waiters = refreshWaiters.slice(0)
			refreshWaiters = []
			refreshInProgress = false
			for (var i = 0; i < waiters.length; i++) waiters[i](err || null)
		}
		// logger.debug('accessTokenExpiresAt', plasmoid.configuration.accessTokenExpiresAt)
		// logger.debug('                 now', Date.now())
		// logger.debug('refreshToken', plasmoid.configuration.refreshToken)
		if (plasmoid.configuration.refreshToken) {
			logger.debug('updateAccessToken')
			fetchNewAccessToken(function(err, data, xhr) {
				var tokenData = null
				if (!err) {
					try {
						tokenData = typeof data === 'string' ? JSON.parse(data) : data
					} catch (parseError) {
						err = "Invalid response while refreshing Google access token."
					}
				}
				if (err || (tokenData && tokenData.error)) {
					logger.log('Error when using refreshToken:', err, data)
					return finishRefresh(err || "Failed to refresh Google access token.")
				}
				if (!tokenData || !tokenData.access_token) {
					return finishRefresh("Missing access token in Google refresh response.")
				}
				logger.debug('onAccessToken', tokenData)

				googleApiSession.applyAccessToken(tokenData)

				finishRefresh(null)
			})
		} else {
			finishRefresh('No refresh token. Cannot update access token.')
		}
	}

	signal accessTokenError(string msg)
	signal newAccessToken()
	signal transactionError(string msg)

	onTransactionError: logger.log(msg)

	function applyAccessToken(data) {
		plasmoid.configuration.accessToken = data.access_token
		plasmoid.configuration.accessTokenType = data.token_type
		plasmoid.configuration.accessTokenExpiresAt = Date.now() + data.expires_in * 1000
		newAccessToken()
	}

	function fetchNewAccessToken(callback) {
		logger.debug('fetchNewAccessToken')
		var url = "https://oauth2.googleapis.com/token"
		Requests.post({
			url: url,
			data: {
				client_id: plasmoid.configuration.sessionClientId,
				client_secret: plasmoid.configuration.sessionClientSecret,
				refresh_token: plasmoid.configuration.refreshToken,
				grant_type: 'refresh_token',
			},
		}, callback)
	}


	//---
	property int errorCount: 0
	function getErrorTimeout(n) {
		// Exponential Backoff
		// 43200 seconds is 12 hours, which is a reasonable polling limit when the API is down.
		// After 6 errors, we wait an entire minute.
		// After 11 errors, we wait an entire hour.
		// After 15 errors, we will have waited 9 hours.
		// 16 errors and above uses the upper limit of 12 hour intervals.
		return 1000 * Math.min(43200, Math.pow(2, n))
	}
	// https://stackoverflow.com/questions/28507619/how-to-create-delay-function-in-qml
	function delay(delayTime, callback) {
		var timer = Qt.createQmlObject("import QtQuick 2.0; Timer {}", googleCalendarManager)
		timer.interval = delayTime
		timer.repeat = false
		timer.triggered.connect(callback)
		timer.triggered.connect(function release(){
			timer.triggered.disconnect(callback)
			timer.triggered.disconnect(release)
			timer.destroy()
		})
		timer.start()
	}
	function waitForErrorTimeout(callback) {
		errorCount += 1
		var timeout = getErrorTimeout(errorCount)
		delay(timeout, function(){
			callback()
		})
	}
}
