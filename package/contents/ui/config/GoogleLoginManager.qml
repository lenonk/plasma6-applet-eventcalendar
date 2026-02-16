import QtQuick 2.0

import "../lib"
import "../lib/Requests.js" as Requests

Item {
	id: session

	readonly property var configPage: {
		var p = session.parent
		while (p) {
			if (p.__eventCalendarConfigPage) return p
			p = p.parent
		}
		return null
	}

	function getCfg(key, fallbackValue) {
		if (configPage) {
			var v = configPage.getConfigValue(key, fallbackValue)
			// Treat empty custom OAuth credentials as "use built-in defaults".
			if ((key === "latestClientId" || key === "latestClientSecret")
				&& (typeof v === "undefined" || v === "")
			) {
				return configPage.getConfigDefaultValue(key, fallbackValue)
			}
			return v
		}
		if (typeof plasmoid !== "undefined"
			&& plasmoid
			&& plasmoid.configuration
			&& typeof plasmoid.configuration[key] !== "undefined"
		) {
			return plasmoid.configuration[key]
		}
		return fallbackValue
	}

	function setCfg(key, value) {
		if (configPage) {
			configPage.setConfigValue(key, value)
		} else {
			plasmoid.configuration[key] = value
		}
	}

	Logger {
		id: logger
		showDebug: !!session.getCfg("debugging", false)
	}

	// Active Session
	readonly property bool isLoggedIn: !!session.getCfg("accessToken", "")
	readonly property bool needsRelog: {
		if (session.getCfg("accessToken", "") && session.getCfg("latestClientId", "") != session.getCfg("sessionClientId", "")) {
			return true
		} else if (!session.getCfg("accessToken", "") && session.getCfg("access_token", "")) {
			return true
		} else {
			return false
		}
	}

	// Data
	property var m_calendarList: ConfigSerializedString {
		id: m_calendarList
		configKey: 'calendarList'
		defaultValue: []
	}
	property alias calendarList: m_calendarList.value

		property var m_calendarIdList: ConfigSerializedString {
		id: m_calendarIdList
		configKey: 'calendarIdList'
		defaultValue: []

			function serialize() {
				var s = value.join(',')
				if (configPage) {
					configPage.setConfigValue(configKey, s)
				} else {
					plasmoid.configuration[configKey] = s
				}
			}
			function deserialize() {
				if (!configValue) {
					value = []
					return
				}
				value = configValue.split(',').filter(function(s) { return !!s })
			}
	}
	property alias calendarIdList: m_calendarIdList.value

	property var m_tasklistList: ConfigSerializedString {
		id: m_tasklistList
		configKey: 'tasklistList'
		defaultValue: []
	}
	property alias tasklistList: m_tasklistList.value

		property var m_tasklistIdList: ConfigSerializedString {
		id: m_tasklistIdList
		configKey: 'tasklistIdList'
		defaultValue: []

			function serialize() {
				var s = value.join(',')
				if (configPage) {
					configPage.setConfigValue(configKey, s)
				} else {
					plasmoid.configuration[configKey] = s
				}
			}
			function deserialize() {
				if (!configValue) {
					value = []
					return
				}
				value = configValue.split(',').filter(function(s) { return !!s })
			}
	}
	property alias tasklistIdList: m_tasklistIdList.value


	//--- Signals
	signal newAccessToken()
	signal sessionReset()
	signal error(string err)


	//---
	readonly property string redirectUri: "http://127.0.0.1:8400/"
	readonly property string authorizationCodeUrl: {
		// Google has blocked the old out-of-band (OOB) redirect flow. We use a loopback
		// redirect URI instead. The widget does not run a local HTTP server; users can
		// copy the `code` from the redirected URL (or paste the full URL) back into the
		// config UI.
		var url = "https://accounts.google.com/o/oauth2/v2/auth"
		url += "?scope=" + encodeURIComponent("https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/tasks")
		url += "&response_type=code"
		url += "&redirect_uri=" + encodeURIComponent(session.redirectUri)
		url += "&access_type=offline"
		url += "&prompt=consent"
		url += "&include_granted_scopes=true"
		url += "&client_id=" + encodeURIComponent(session.getCfg("latestClientId", ""))
		return url
	}

	function fetchAccessToken(args) {
		var url = "https://oauth2.googleapis.com/token"
		Requests.post({
				url: url,
				data: {
					client_id: session.getCfg("latestClientId", ""),
					client_secret: session.getCfg("latestClientSecret", ""),
					code: args.authorizationCode,
					grant_type: 'authorization_code',
					redirect_uri: session.redirectUri,
				},
		}, function(err, data, xhr) {
			logger.debug('/token Response', data)

			// Check for errors
			if (err) {
				handleError(err, null)
				return
			}
			try {
				data = JSON.parse(data)
			} catch (e) {
				handleError('Error parsing /token data as JSON', null)
				return
			}
			if (data && data.error) {
				handleError(err, data)
				return
			}

			// Ready
			updateAccessToken(data)
		})
		}

		function updateAccessToken(data) {
			session.setCfg("sessionClientId", session.getCfg("latestClientId", ""))
			session.setCfg("sessionClientSecret", session.getCfg("latestClientSecret", ""))
			session.setCfg("accessToken", data.access_token || "")
			session.setCfg("accessTokenType", data.token_type || "")
			session.setCfg("accessTokenExpiresAt", Date.now() + (data.expires_in || 0) * 1000)
			// Google may omit refresh_token on subsequent logins unless prompt=consent.
			// Don't clobber an existing valid refresh token if it's missing.
			if (data.refresh_token) {
				session.setCfg("refreshToken", data.refresh_token)
			}
			newAccessToken()
		}

	onNewAccessToken: updateData()

	function updateData() {
		updateCalendarList()
		updateTasklistList()
	}

		function updateCalendarList() {
			logger.debug('updateCalendarList')
			logger.debug('accessToken', session.getCfg("accessToken", ""))
			fetchGCalCalendars({
				accessToken: session.getCfg("accessToken", ""),
			}, function(err, data, xhr) {
			// Check for errors
			if (err || data.error) {
				handleError(err, data)
				return
			}
			m_calendarList.value = data.items
		})
	}

	function fetchGCalCalendars(args, callback) {
		var url = 'https://www.googleapis.com/calendar/v3/users/me/calendarList'
		Requests.getJSON({
			url: url,
			headers: {
				"Authorization": "Bearer " + args.accessToken,
			}
		}, function(err, data, xhr) {
			// console.log('fetchGCalCalendars.response', err, data, xhr && xhr.status)
			if (!err && data && data.error) {
				return callback('fetchGCalCalendars error', data, xhr)
			}
			logger.debugJSON('fetchGCalCalendars.response.data', data)
			callback(err, data, xhr)
		})
	}

		function updateTasklistList() {
			logger.debug('updateTasklistList')
			logger.debug('accessToken', session.getCfg("accessToken", ""))
			fetchGoogleTasklistList({
				accessToken: session.getCfg("accessToken", ""),
			}, function(err, data, xhr) {
			// Check for errors
			if (err || data.error) {
				handleError(err, data)
				return
			}
			m_tasklistList.value = data.items
		})
	}

	function fetchGoogleTasklistList(args, callback) {
		var url = 'https://www.googleapis.com/tasks/v1/users/@me/lists'
		Requests.getJSON({
			url: url,
			headers: {
				"Authorization": "Bearer " + args.accessToken,
			}
		}, function(err, data, xhr) {
			console.log('fetchGoogleTasklistList.response', err, data, xhr && xhr.status)
			if (!err && data && data.error) {
				return callback('fetchGoogleTasklistList error', data, xhr)
			}
			logger.debugJSON('fetchGoogleTasklistList.response.data', data)
			callback(err, data, xhr)
		})
	}

		function logout() {
			session.setCfg("sessionClientId", "")
			session.setCfg("sessionClientSecret", "")
			session.setCfg("accessToken", "")
			session.setCfg("accessTokenType", "")
			session.setCfg("accessTokenExpiresAt", 0)
			session.setCfg("refreshToken", "")

			// Delete relevant data
			// TODO: only target google calendar data
			// TODO: Make a signal?
			session.setCfg("agendaNewEventLastCalendarId", "")
			calendarList = []
			calendarIdList = []
			tasklistList = []
		tasklistIdList = []
		sessionReset()
	}

	// https://developers.google.com/calendar/v3/errors
	function handleError(err, data) {
		if (data && data.error && data.error_description) {
			var errorMessage = '' + data.error + ' (' + data.error_description + ')'
			session.error(errorMessage)
		} else if (data && data.error && data.error.message && typeof data.error.code !== "undefined") {
			var errorMessage = '' + data.error.message + ' (' + data.error.code + ')'
			session.error(errorMessage)
		} else if (err) {
			session.error(err)
		}
	}
}
