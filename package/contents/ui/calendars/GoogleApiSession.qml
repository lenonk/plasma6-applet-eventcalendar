import QtQuick 2.0

import "../ErrorType.js" as ErrorType
import "../lib/Requests.js" as Requests

QtObject {
	id: googleApiSession

	// Empty for the first account, "account2" for the second one.
	property string accountPrefix: ""
	function cfgKey(key) {
		return accountPrefix ? accountPrefix + key.charAt(0).toUpperCase() + key.slice(1) : key
	}
	function cfg(key) {
		return plasmoid.configuration[cfgKey(key)]
	}

	readonly property string accessToken: plasmoid.configuration[cfgKey("accessToken")] || ""
	property bool refreshInProgress: false
	property var refreshWaiters: []

	//--- Refresh Credentials
	// callback(err, xhr): err is null when the token is usable.
	function checkAccessToken(callback) {
		logger.debug('checkAccessToken')
		if (cfg("accessTokenExpiresAt") < Date.now() + 5000) {
			updateAccessToken(callback)
		} else {
			callback(null)
		}
	}

	function updateAccessToken(callback) {
		refreshWaiters.push(callback)
		if (refreshInProgress) return
		refreshInProgress = true
		function finishRefresh(err, xhr) {
			var waiters = refreshWaiters.slice(0)
			refreshWaiters = []
			refreshInProgress = false
			if (err) {
				googleApiSession.accessTokenError("" + err)
			}
			for (var i = 0; i < waiters.length; i++) waiters[i](err || null, xhr || null)
		}
		// logger.debug('accessTokenExpiresAt', cfg("accessTokenExpiresAt"))
		// logger.debug('                 now', Date.now())
		// logger.debug('refreshToken', cfg("refreshToken"))
		if (cfg("refreshToken")) {
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
					return finishRefresh(err || "Failed to refresh Google access token.", xhr)
				}
				if (!tokenData || !tokenData.access_token) {
					return finishRefresh("Missing access token in Google refresh response.", xhr)
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

	onTransactionError: function(msg) { logger.log(msg) }

	// Maps a checkAccessToken() failure to { message, errorType } for CalendarManager.error().
	function describeTokenError(err, xhr) {
		var httpCode = xhr ? xhr.status : -1
		if (httpCode === 0) {
			return {
				message: i18n("HTTP Error %1: %2", 0, i18n("Could not connect")) + '\n' + i18n("Will try again soon."),
				errorType: ErrorType.NetworkError,
			}
		} else if (httpCode >= 500) {
			return {
				message: i18n("HTTP Error %1: %2", httpCode, "" + err) + '\n' + i18n("Will try again soon."),
				errorType: ErrorType.ServerError,
			}
		}
		return {
			message: i18n("Could not refresh the Google login. Please log in to Google again."),
			errorType: ErrorType.ClientError,
		}
	}

	function applyAccessToken(data) {
		plasmoid.configuration[cfgKey("accessToken")] = data.access_token
		plasmoid.configuration[cfgKey("accessTokenType")] = data.token_type
		plasmoid.configuration[cfgKey("accessTokenExpiresAt")] = Date.now() + (data.expires_in || 0) * 1000
		newAccessToken()
	}

	function fetchNewAccessToken(callback) {
		logger.debug('fetchNewAccessToken')
		var url = "https://oauth2.googleapis.com/token"
		Requests.post({
			url: url,
			data: {
				client_id: cfg("sessionClientId"),
				client_secret: cfg("sessionClientSecret"),
				refresh_token: cfg("refreshToken"),
				grant_type: 'refresh_token',
			},
		}, callback)
	}
}
