import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import ".."
import "../lib"
import "../calendars/GoogleAccounts.js" as GoogleAccounts

ConfigPage {
	id: page
	// showAppletVersion: true

	property bool showHelp: false
	property bool showAdvanced: false
	property bool oauthBusy: false
	property bool syncingSelectionModels: false

	// Edited slot: 0 is account 1, n is GoogleAccounts.extraPrefixes[n - 1].
	property int accountIndex: 0
	function loginManagerAt(slot) {
		if (slot <= 0) return googleLoginManager
		return extraLoginManagers.itemAt(slot - 1) || null
	}
	readonly property var lm: {
		extraLoginManagers.count // re-evaluate once the extra managers exist
		return loginManagerAt(accountIndex) || googleLoginManager
	}
	function syncAccountTabBar() {
		accountTabBar.currentIndex = Math.max(0, visibleSlots.indexOf(accountIndex))
	}
	onAccountIndexChanged: syncAccountTabBar()
	onLmChanged: {
		clearStatus()
		rebuildCalendarsModel()
		rebuildTasklistsModel()
	}

	// Tabs: the first account, every connected extra account, then one free slot to add an account.
	readonly property var visibleSlots: {
		var slots = [0]
		var freeSlot = -1
		for (var i = 1; i <= extraLoginManagers.count; i++) {
			var m = loginManagerAt(i)
			if (m && m.isLoggedIn) {
				slots.push(i)
			} else if (freeSlot < 0) {
				freeSlot = i
			}
		}
		if (freeSlot >= 0 && googleLoginManager.isLoggedIn) {
			slots.push(freeSlot)
		}
		return slots
	}
	onVisibleSlotsChanged: {
		if (visibleSlots.indexOf(accountIndex) < 0) {
			accountIndex = 0
		}
		syncAccountTabBar()
	}

	function accountTabLabel(slot) {
		var m = loginManagerAt(slot)
		if (m && m.isLoggedIn) {
			return accountEmail(m) || i18n("Account %1", slot + 1)
		}
		return slot === 0 ? i18n("Account 1") : i18n("+ Add account")
	}

	function accountEmail(manager) {
		var list = manager.calendarList || []
		for (var i = 0; i < list.length; i++) {
			if (list[i] && list[i].primary === true) return list[i].id
		}
		return ""
	}

	function sortByKey(key, a, b) {
		if (typeof a[key] === "string") {
			return a[key].toLowerCase().localeCompare(b[key].toLowerCase())
		} else if (typeof a[key] === "number") {
			return a[key] - b[key]
		}
		return 0
	}

	function sortArr(arr, predicate) {
		if (!Array.isArray(arr)) return []
		if (typeof predicate === "string") { // predicate is a key
			predicate = sortByKey.bind(null, predicate)
		}
		return arr.concat().sort(predicate)
	}

	function unique(arr) {
		var seen = ({})
		var out = []
		for (var i = 0; i < arr.length; i++) {
			var v = arr[i]
			if (seen[v]) continue
			seen[v] = true
			out.push(v)
		}
		return out
	}

	function clearStatus() {
		statusMessage.visible = false
		statusMessage.text = ""
		statusMessage.type = Kirigami.MessageType.Information
	}

	function showStatus(text, type) {
		statusMessage.text = text
		statusMessage.type = type || Kirigami.MessageType.Information
		statusMessage.visible = !!text
	}

	function localizedErrorMessage(text) {
		var msg = ("" + (text || "")).trim()
		if (!msg) {
			return ""
		}

		if (msg === "Error parsing /token data as JSON") {
			return i18n("Google login failed (invalid response).")
		}
		if (msg === "fetchGCalCalendars error" || msg === "fetchGoogleTasklistList error") {
			return i18n("Google API request failed.")
		}
		if (msg === "Missing required argument: --client-id") {
			return i18n("Missing required argument: --client-id")
		}
		if (msg === "Failed to open web browser via xdg-open.") {
			return i18n("Failed to open web browser via xdg-open.")
		}

		var m = /^OAuth failed \(requestFailed=(\d+)\)\.$/.exec(msg)
		if (m) {
			return i18n("OAuth failed (requestFailed=%1).", m[1])
		}
		m = /^OAuth timed out after (\d+) seconds\.$/.exec(msg)
		if (m) {
			return i18n("OAuth timed out after %1 seconds.", m[1])
		}
		m = /^Failed to listen on http:\/\/127\.0\.0\.1:(\d+)\/ \(port in use\?\)$/.exec(msg)
		if (m) {
			return i18n("Failed to listen on http://127.0.0.1:%1/ (port in use?)", m[1])
		}
		m = /^HTTP Error (\d+)$/.exec(msg)
		if (m) {
			return i18n("HTTP Error %1", m[1])
		}

		return msg
	}

	function updateCalendarIdListFromModel() {
		var ids = []
		for (var i = 0; i < calendarsModel.count; i++) {
			var item = calendarsModel.get(i)
			if (item.show) {
				ids.push(item.isPrimary && !page.lm.accountPrefix ? "primary" : item.calendarId)
			}
		}
		var selectedIds = unique(ids)
		var selectedString = selectedIds.join(",")
		var managerString = (page.lm.calendarIdList || []).join(",")
		if (managerString !== selectedString) {
			page.lm.calendarIdList = selectedIds
		}
		// Persist to cfg_* explicitly so KCM reliably marks the page dirty (Apply enabled).
		var calendarIdListKey = page.lm.cfgKey("calendarIdList")
		if ((page.getConfigValue(calendarIdListKey, "") || "") !== selectedString) {
			page.setConfigValue(calendarIdListKey, selectedString)
		}
	}

	function updateTasklistIdListFromModel() {
		var ids = []
		for (var i = 0; i < tasklistsModel.count; i++) {
			var item = tasklistsModel.get(i)
			if (item.show) {
				ids.push(item.tasklistId)
			}
		}
		var selectedIds = unique(ids)
		var selectedString = selectedIds.join(",")
		var managerString = (page.lm.tasklistIdList || []).join(",")
		if (managerString !== selectedString) {
			page.lm.tasklistIdList = selectedIds
		}
		// Persist to cfg_* explicitly so KCM reliably marks the page dirty (Apply enabled).
		var tasklistIdListKey = page.lm.cfgKey("tasklistIdList")
		if ((page.getConfigValue(tasklistIdListKey, "") || "") !== selectedString) {
			page.setConfigValue(tasklistIdListKey, selectedString)
		}
	}

	function rebuildCalendarsModel() {
		page.syncingSelectionModels = true
		calendarsModel.clear()
		var sorted = sortArr(page.lm.calendarList || [], "summary")
		var selected = page.lm.calendarIdList || []
		for (var i = 0; i < sorted.length; i++) {
			var item = sorted[i]
			var isPrimary = item && item.primary === true
			var isShown = selected.indexOf(item.id) >= 0 || (isPrimary && selected.indexOf("primary") >= 0)
			calendarsModel.append({
				calendarId: item.id,
				name: item.summary || "",
				backgroundColor: item.backgroundColor || "",
				foregroundColor: item.foregroundColor || "",
				show: isShown,
				isReadOnly: item.accessRole === "reader",
				isPrimary: isPrimary,
			})
		}
		page.syncingSelectionModels = false
	}

	function rebuildTasklistsModel() {
		page.syncingSelectionModels = true
		tasklistsModel.clear()
		var sorted = sortArr(page.lm.tasklistList || [], "title")
		var selected = page.lm.tasklistIdList || []
		for (var i = 0; i < sorted.length; i++) {
			var item = sorted[i]
			var isShown = selected.indexOf(item.id) >= 0
			tasklistsModel.append({
				tasklistId: item.id,
				name: item.title || "",
				backgroundColor: Kirigami.Theme.highlightColor.toString(),
				foregroundColor: Kirigami.Theme.highlightedTextColor.toString(),
				show: isShown,
				isReadOnly: false,
			})
		}
		page.syncingSelectionModels = false
	}

	function startOAuthHelper() {
		clearStatus()
		showStatus(i18n("Opening the browser for Google login…"), Kirigami.MessageType.Information)
		oauthBusy = true
		var loginManager = page.lm

		var helperPath = execUtil.urlToLocalPath(Qt.resolvedUrl("../../bin/eventcalendar-google-oauth"))
		var clientId = page.lm.getCfg("latestClientId", "")
		var clientSecret = page.lm.getCfg("latestClientSecret", "")

		// Use a local helper so we can run a proper loopback OAuth flow (no "copy the code" UX).
		execUtil.exec([
			helperPath,
			"--client-id", clientId,
			"--client-secret", clientSecret,
		], function(cmd, exitCode, exitStatus, stdout, stderr) {
			oauthBusy = false

			if (exitCode !== 0) {
				var msg = ("" + (stderr || stdout || "")).trim()
				if (exitCode === 126 || exitCode === 127) {
					page.showAdvanced = true
					page.showHelp = true
					showStatus(i18n("Google login helper is unavailable. Use the Advanced manual login method below."), Kirigami.MessageType.Warning)
					return
				}
				showStatus(page.localizedErrorMessage(msg) || i18n("Google login failed."), Kirigami.MessageType.Error)
				return
			}

			// The browser launched by the helper may print to the same stdout; use the last JSON line.
			var lines = ("" + (stdout || "")).split("\n")
			var line = ""
			for (var i = lines.length - 1; i >= 0; i--) {
				var candidate = lines[i].trim()
				if (candidate.indexOf("{") === 0) {
					line = candidate
					break
				}
			}
			var data = null
			try {
				data = JSON.parse(line)
			} catch (e) {
				showStatus(i18n("Google login failed (invalid response)."), Kirigami.MessageType.Error)
				return
			}

			if (!data || !data.access_token) {
				showStatus(i18n("Google login failed (missing access token)."), Kirigami.MessageType.Error)
				return
			}

			loginManager.updateAccessToken(data)
			showStatus(i18n("Google login complete. Click Apply to save."), Kirigami.MessageType.Positive)
		})
	}

	ExecUtil { id: execUtil }

	GoogleLoginManager {
		id: googleLoginManager

		onError: function(err) { showStatus(page.localizedErrorMessage(err), Kirigami.MessageType.Error) }
		// Deferred: a checkbox's onToggled changes the id list, and rebuilding would destroy that delegate mid-handler.
		onCalendarListChanged: if (page.lm === googleLoginManager) Qt.callLater(rebuildCalendarsModel)
		onTasklistListChanged: if (page.lm === googleLoginManager) Qt.callLater(rebuildTasklistsModel)
		onCalendarIdListChanged: if (page.lm === googleLoginManager) Qt.callLater(rebuildCalendarsModel)
		onTasklistIdListChanged: if (page.lm === googleLoginManager) Qt.callLater(rebuildTasklistsModel)
	}

	// Holds the extra accounts' managers; an Item parent lets them find this config page.
	Item {
		visible: false
		Repeater {
			id: extraLoginManagers
			model: GoogleAccounts.extraPrefixes
			delegate: GoogleLoginManager {
				id: extraLoginManager
				accountPrefix: modelData

				onError: function(err) { showStatus(page.localizedErrorMessage(err), Kirigami.MessageType.Error) }
				onCalendarListChanged: if (page.lm === extraLoginManager) Qt.callLater(rebuildCalendarsModel)
				onTasklistListChanged: if (page.lm === extraLoginManager) Qt.callLater(rebuildTasklistsModel)
				onCalendarIdListChanged: if (page.lm === extraLoginManager) Qt.callLater(rebuildCalendarsModel)
				onTasklistIdListChanged: if (page.lm === extraLoginManager) Qt.callLater(rebuildTasklistsModel)
			}
		}
	}

	ListModel { id: calendarsModel }
	ListModel { id: tasklistsModel }

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.largeSpacing

		Kirigami.InlineMessage {
			id: statusMessage
			Layout.fillWidth: true
			visible: false
			type: Kirigami.MessageType.Information
			text: ""
			showCloseButton: true
		}

		QQC2.TabBar {
			id: accountTabBar
			Layout.fillWidth: true
			enabled: !page.oauthBusy

			Repeater {
				model: page.visibleSlots
				delegate: QQC2.TabButton {
					text: page.accountTabLabel(modelData)
					onClicked: page.accountIndex = modelData
				}
			}
		}

		ConfigSection {
			title: i18n("Login")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.Label {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					wrapMode: Text.Wrap
					opacity: 0.85
					text: page.lm.isLoggedIn && page.accountEmail(page.lm)
						? i18n("Connected as %1.", page.accountEmail(page.lm))
						: i18n("Connect your Google account to show Google Calendar events in the agenda.")
				}

				RowLayout {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					spacing: Kirigami.Units.smallSpacing

					QQC2.Button {
						text: page.lm.isLoggedIn ? i18n("Logout") : i18n("Login in Browser")
						icon.name: page.lm.isLoggedIn ? "system-log-out" : "internet-services"
						enabled: !oauthBusy
						onClicked: {
							if (page.lm.isLoggedIn) {
								page.lm.logout()
								clearStatus()
								showStatus(i18n("Logged out. Click Apply to save."), Kirigami.MessageType.Information)
							} else {
								startOAuthHelper()
							}
						}
					}

					QQC2.Button {
						text: page.showHelp ? i18n("Hide help") : i18n("Show help")
						checkable: true
						checked: page.showHelp
						onToggled: page.showHelp = checked
					}

					QQC2.Button {
						text: i18n("Advanced")
						checkable: true
						checked: page.showAdvanced
						onToggled: page.showAdvanced = checked
					}

					Item { Layout.fillWidth: true }

					QQC2.BusyIndicator {
						running: page.oauthBusy
						visible: page.oauthBusy
					}
				}

				Kirigami.InlineMessage {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					visible: page.lm.needsRelog
					type: Kirigami.MessageType.Warning
					text: i18n("Widget has been updated. Please logout and login again.")
				}

					Kirigami.InlineMessage {
						Kirigami.FormData.label: ""
						Layout.fillWidth: true
						visible: page.showHelp
						type: Kirigami.MessageType.Information
						text: page.lm.isLoggedIn
							? i18n("You are connected. Use Refresh below if calendars/tasks changed, then click Apply to save selection updates.")
							: i18n("A web browser will open for Google login. If the helper cannot start (missing binary, port in use), enable Advanced and use the manual code method.")
					}
				}
			}

		ConfigSection {
			title: i18n("Calendars")
			visible: page.lm.isLoggedIn

			RowLayout {
				Layout.fillWidth: true
				spacing: Kirigami.Units.smallSpacing

				QQC2.Label {
					Layout.fillWidth: true
					opacity: 0.85
					wrapMode: Text.Wrap
					text: i18n("Choose which calendars to show.")
				}

				QQC2.Button {
					icon.name: "view-refresh"
					text: i18n("Refresh")
					onClicked: page.lm.updateCalendarList()
				}
			}

			ColumnLayout {
				Layout.fillWidth: true
				spacing: Kirigami.Units.smallSpacing

					Repeater {
						model: calendarsModel
						delegate: QQC2.CheckBox {
							Layout.fillWidth: true
							checked: model.show
							onToggled: {
								if (page.syncingSelectionModels) {
									return
								}
								calendarsModel.setProperty(index, "show", checked)
								updateCalendarIdListFromModel()
							}

						contentItem: RowLayout {
							spacing: Kirigami.Units.smallSpacing

							Rectangle {
								Layout.alignment: Qt.AlignVCenter
								implicitWidth: Kirigami.Units.iconSizes.smallMedium
								implicitHeight: Kirigami.Units.iconSizes.smallMedium
								radius: 2
								color: model.backgroundColor || "transparent"
								border.width: model.backgroundColor ? 0 : 1
								border.color: Kirigami.Theme.disabledTextColor
							}

							QQC2.Label {
								Layout.fillWidth: true
								text: model.name
								elide: Text.ElideRight
							}

							LockIcon {
								Layout.alignment: Qt.AlignVCenter
								visible: model.isReadOnly
								implicitWidth: Kirigami.Units.iconSizes.smallMedium
								implicitHeight: Kirigami.Units.iconSizes.smallMedium
							}
						}
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Tasks")
			visible: page.lm.isLoggedIn

			RowLayout {
				Layout.fillWidth: true
				spacing: Kirigami.Units.smallSpacing

				QQC2.Label {
					Layout.fillWidth: true
					opacity: 0.85
					wrapMode: Text.Wrap
					text: i18n("Choose which task lists to show.")
				}

				QQC2.Button {
					icon.name: "view-refresh"
					text: i18n("Refresh")
					onClicked: page.lm.updateTasklistList()
				}
			}

			ColumnLayout {
				Layout.fillWidth: true
				spacing: Kirigami.Units.smallSpacing

					Repeater {
						model: tasklistsModel
						delegate: QQC2.CheckBox {
							Layout.fillWidth: true
							checked: model.show
							onToggled: {
								if (page.syncingSelectionModels) {
									return
								}
								tasklistsModel.setProperty(index, "show", checked)
								updateTasklistIdListFromModel()
							}

						contentItem: RowLayout {
							spacing: Kirigami.Units.smallSpacing

							Rectangle {
								Layout.alignment: Qt.AlignVCenter
								implicitWidth: Kirigami.Units.iconSizes.smallMedium
								implicitHeight: Kirigami.Units.iconSizes.smallMedium
								radius: 2
								color: model.backgroundColor || Kirigami.Theme.highlightColor
							}

							QQC2.Label {
								Layout.fillWidth: true
								text: model.name
								elide: Text.ElideRight
							}
						}
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Options")
			visible: page.lm.isLoggedIn

			Kirigami.FormLayout {
				Layout.fillWidth: true

				ConfigRadioButtonGroup {
					Kirigami.FormData.label: i18n("Event click:")
					configKey: "googleEventClickAction"
					model: [
						{ value: "WebEventView", text: i18n("Open web event view") },
						{ value: "WebMonthView", text: i18n("Open web month view") },
					]
				}

				ConfigCheckBox {
					Kirigami.FormData.label: ""
					configKey: "googleHideGoalsDesc"
					text: i18n("Hide the “Goals in Google Calendar” description")
				}

				ConfigColor {
					Kirigami.FormData.label: ""
					configKey: "googleBirthdayColor"
					label: i18n("Birthdays")
					Layout.fillWidth: true
				}

				ConfigCheckBox {
					Kirigami.FormData.label: ""
					configKey: "googleTasksHideCompleted"
					text: i18n("Hide completed tasks")
				}
			}
		}

		ConfigSection {
			title: i18n("Advanced")
			visible: page.showAdvanced

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.Label {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					wrapMode: Text.Wrap
					opacity: 0.85
					text: i18n("By default, the widget uses built-in OAuth credentials. Custom credentials are for developers only.")
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Client ID:")

					QQC2.TextField {
						Layout.fillWidth: true
						text: "" + (page.cfg_latestClientId || "")
						onTextEdited: page.cfg_latestClientId = text
					}

					QQC2.Button {
						text: i18n("Reset")
						onClicked: page.cfg_latestClientId = ""
					}
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Client secret:")

					QQC2.TextField {
						Layout.fillWidth: true
						echoMode: TextInput.Password
						text: "" + (page.cfg_latestClientSecret || "")
						onTextEdited: page.cfg_latestClientSecret = text
					}

					QQC2.Button {
						text: i18n("Reset")
						onClicked: page.cfg_latestClientSecret = ""
					}
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Use manual code flow")
					checked: page.showHelp
					onToggled: page.showHelp = checked
				}

				ColumnLayout {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					visible: page.showHelp && !page.lm.isLoggedIn
					spacing: Kirigami.Units.smallSpacing

					QQC2.Label {
						Layout.fillWidth: true
						wrapMode: Text.Wrap
						opacity: 0.85
						text: i18n("If the browser shows a connection error after you approve access, copy the full URL (or just the “code” parameter) and paste it below.")
					}

					LinkText {
						Layout.fillWidth: true
						text: i18n("Open <a href=\"%1\">Google login</a> in your browser.", page.lm.authorizationCodeUrl)
						wrapMode: Text.Wrap
					}

					RowLayout {
						Layout.fillWidth: true

						QQC2.TextField {
							id: authorizationCodeInput
							Layout.fillWidth: true
							placeholderText: i18n("Paste redirected URL or code here")
						}

						QQC2.Button {
							text: i18n("Submit")
							onClicked: {
								var text = (authorizationCodeInput.text || "").trim()
								if (!text) {
									showStatus(i18n("Please paste a URL or authorization code."), Kirigami.MessageType.Warning)
									return
								}
								// Accept either a full URL or just the code itself.
								var code = text
								var idx = text.indexOf("code=")
								if (idx >= 0) {
									code = text.substr(idx + "code=".length)
									var amp = code.indexOf("&")
									if (amp >= 0) code = code.substr(0, amp)
									code = decodeURIComponent(code)
								}
								page.lm.fetchAccessToken({ authorizationCode: code })
							}
						}
					}
				}
			}
		}
	}

	Component.onCompleted: {
		// Accounts connected before their calendar list was saved: fetch it (also gives the tab its email).
		for (var i = 0; i <= extraLoginManagers.count; i++) {
			var m = loginManagerAt(i)
			if (m && m.isLoggedIn && (m.calendarList || []).length === 0) {
				m.updateData()
			}
		}
		if (page.lm.isLoggedIn) {
			rebuildCalendarsModel()
			rebuildTasklistsModel()
		}
	}
}
