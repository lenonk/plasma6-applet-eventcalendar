import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import ".."
import "../lib"

ConfigPage {
	id: page
	// showAppletVersion: true

	property bool showHelp: false
	property bool showAdvanced: false
	property bool oauthBusy: false
	property bool syncingSelectionModels: false

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

	function updateCalendarIdListFromModel() {
		var ids = []
		for (var i = 0; i < calendarsModel.count; i++) {
			var item = calendarsModel.get(i)
			if (item.show) {
				ids.push(item.isPrimary ? "primary" : item.calendarId)
			}
		}
		var selectedIds = unique(ids)
		var selectedString = selectedIds.join(",")
		var managerString = (googleLoginManager.calendarIdList || []).join(",")
		if (managerString !== selectedString) {
			googleLoginManager.calendarIdList = selectedIds
		}
		// Persist to cfg_* explicitly so KCM reliably marks the page dirty (Apply enabled).
		if ((page.getConfigValue("calendarIdList", "") || "") !== selectedString) {
			page.setConfigValue("calendarIdList", selectedString)
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
		var managerString = (googleLoginManager.tasklistIdList || []).join(",")
		if (managerString !== selectedString) {
			googleLoginManager.tasklistIdList = selectedIds
		}
		// Persist to cfg_* explicitly so KCM reliably marks the page dirty (Apply enabled).
		if ((page.getConfigValue("tasklistIdList", "") || "") !== selectedString) {
			page.setConfigValue("tasklistIdList", selectedString)
		}
	}

	function rebuildCalendarsModel() {
		page.syncingSelectionModels = true
		calendarsModel.clear()
		var sorted = sortArr(googleLoginManager.calendarList || [], "summary")
		var selected = googleLoginManager.calendarIdList || []
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
		var sorted = sortArr(googleLoginManager.tasklistList || [], "title")
		var selected = googleLoginManager.tasklistIdList || []
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

		var helperPath = execUtil.urlToLocalPath(Qt.resolvedUrl("../../bin/eventcalendar-google-oauth"))
		var clientId = googleLoginManager.getCfg("latestClientId", "")
		var clientSecret = googleLoginManager.getCfg("latestClientSecret", "")

		// Use a local helper so we can run a proper loopback OAuth flow (no "copy the code" UX).
		execUtil.exec([
			helperPath,
			"--client-id", clientId,
			"--client-secret", clientSecret,
		], function(cmd, exitCode, exitStatus, stdout, stderr) {
			oauthBusy = false

			if (exitCode !== 0) {
				var msg = ("" + (stderr || stdout || "")).trim()
				showStatus(msg || i18n("Google login failed."), Kirigami.MessageType.Error)
				return
			}

			var line = ("" + (stdout || "")).trim()
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

			googleLoginManager.updateAccessToken(data)
			showStatus(i18n("Google login complete. Click Apply to save."), Kirigami.MessageType.Positive)
		})
	}

	ExecUtil { id: execUtil }

	GoogleLoginManager {
		id: googleLoginManager

		onError: showStatus(err, Kirigami.MessageType.Error)
		onCalendarListChanged: rebuildCalendarsModel()
		onTasklistListChanged: rebuildTasklistsModel()
		onCalendarIdListChanged: rebuildCalendarsModel()
		onTasklistIdListChanged: rebuildTasklistsModel()
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

		ConfigSection {
			title: i18n("Login")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.Label {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					wrapMode: Text.Wrap
					opacity: 0.85
					text: i18n("Connect your Google account to show Google Calendar events in the agenda.")
				}

				RowLayout {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					spacing: Kirigami.Units.smallSpacing

					QQC2.Button {
						text: googleLoginManager.isLoggedIn ? i18n("Logout") : i18n("Login in Browser")
						icon.name: googleLoginManager.isLoggedIn ? "system-log-out" : "internet-services"
						enabled: !oauthBusy
						onClicked: {
							if (googleLoginManager.isLoggedIn) {
								googleLoginManager.logout()
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
					visible: googleLoginManager.needsRelog
					type: Kirigami.MessageType.Warning
					text: i18n("Widget has been updated. Please logout and login again.")
				}

					Kirigami.InlineMessage {
						Kirigami.FormData.label: ""
						Layout.fillWidth: true
						visible: page.showHelp
						type: Kirigami.MessageType.Information
						text: googleLoginManager.isLoggedIn
							? i18n("You are connected. Use Refresh below if calendars/tasks changed, then click Apply to save selection updates.")
							: i18n("A web browser will open for Google login. If the helper cannot start (missing binary, port in use), enable Advanced and use the manual code method.")
					}
				}
			}

		ConfigSection {
			title: i18n("Calendars")
			visible: googleLoginManager.isLoggedIn

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
					onClicked: googleLoginManager.updateCalendarList()
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
			visible: googleLoginManager.isLoggedIn

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
					onClicked: googleLoginManager.updateTasklistList()
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
			visible: googleLoginManager.isLoggedIn

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
					visible: page.showHelp && !googleLoginManager.isLoggedIn
					spacing: Kirigami.Units.smallSpacing

					QQC2.Label {
						Layout.fillWidth: true
						wrapMode: Text.Wrap
						opacity: 0.85
						text: i18n("If the browser shows a connection error after you approve access, copy the full URL (or just the “code” parameter) and paste it below.")
					}

					LinkText {
						Layout.fillWidth: true
						text: i18n("Open <a href=\"%1\">Google login</a> in your browser.", googleLoginManager.authorizationCodeUrl)
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
								googleLoginManager.fetchAccessToken({ authorizationCode: code })
							}
						}
					}
				}
			}
		}
	}

	Component.onCompleted: {
		if (googleLoginManager.isLoggedIn) {
			rebuildCalendarsModel()
			rebuildTasklistsModel()
		}
	}
}
