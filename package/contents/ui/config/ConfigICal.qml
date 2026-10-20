import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import QtCore
import org.kde.kirigami as Kirigami

import ".."
import "../lib"

ConfigPage {
	id: page

	// Unique per click so two new calendars don't share a file.
	function defaultLocalIcsPath() {
		var filename = "calendar-" + Date.now() + ".ics"
		var home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
		if (!home || home.length === 0) {
			return filename
		}
		return executable.urlToLocalPath(home) + "/.local/share/plasma_org.kde.plasma.eventcalendar/" + filename
	}

	ExecUtil { id: executable }

	Base64JsonListModel {
		id: calendarsModel
		configPage: page
		configKey: "icalCalendarList"

		function addCalendar() {
			addItem({
				url: "",
				name: i18n("Calendar"),
				backgroundColor: "" + Kirigami.Theme.highlightColor,
				show: true,
				isReadOnly: true,
			})
		}

		function addNewCalendar() {
			var path = page.defaultLocalIcsPath()
			var scriptPath = executable.urlToLocalPath(Qt.resolvedUrl("../../scripts/icsjson.py"))
			executable.exec(['python3', scriptPath, '--url=' + path, 'create'], function(cmd, exitCode, exitStatus, stdout, stderr) {
				if (exitCode) {
					console.log("[eventcalendar] Could not create", path, stderr)
				}
			})
			addItem({
				url: path,
				name: i18n("Calendar"),
				backgroundColor: "" + Kirigami.Theme.highlightColor,
				show: true,
				isReadOnly: true,
			})
		}
	}

	Kirigami.InlineMessage {
		Layout.fillWidth: true
		type: Kirigami.MessageType.Information
		text: i18n("Add local or remote .ics calendars. Changes are applied when you click Apply. Requires the python icalendar module (python-icalendar / python3-icalendar).")
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.smallSpacing

		Kirigami.Heading {
			Layout.fillWidth: true
			level: 2
			text: i18n("Calendars")
		}

		QQC2.Button {
			icon.name: "resource-calendar-insert"
			text: i18n("Add")
			onClicked: calendarsModel.addCalendar()
		}
		QQC2.Button {
			icon.name: "resource-calendar-insert"
			text: i18n("New")
			onClicked: calendarsModel.addNewCalendar()
		}
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.largeSpacing

		Repeater {
			model: calendarsModel

			delegate: ColumnLayout {
				Layout.fillWidth: true
				spacing: Kirigami.Units.smallSpacing

				RowLayout {
					Layout.fillWidth: true
					spacing: Kirigami.Units.smallSpacing

					QQC2.CheckBox {
						checked: show
						onClicked: calendarsModel.setItemProperty(index, "show", checked)
					}

					Rectangle {
						implicitWidth: Kirigami.Units.iconSizes.smallMedium
						implicitHeight: implicitWidth
						radius: 4
						color: model.backgroundColor
					}

					QQC2.TextField {
						id: labelTextField
						Layout.fillWidth: true
						text: model.name
						placeholderText: i18n("Calendar name")
						onTextEdited: calendarsModel.setItemProperty(index, "name", text)
					}

					QQC2.ToolButton {
						icon.name: "trash-empty"
						text: i18n("Remove")
						display: QQC2.AbstractButton.IconOnly
						onClicked: calendarsModel.removeIndex(index)
					}
				}

				RowLayout {
					Layout.fillWidth: true
					spacing: Kirigami.Units.smallSpacing

					QQC2.TextField {
						id: calendarUrlField
						Layout.fillWidth: true
						text: model.url
						placeholderText: i18n("Path or URL to .ics file")
						onTextEdited: calendarsModel.setItemProperty(index, "url", text)
					}

					QQC2.Button {
						icon.name: "folder-open"
						text: i18n("Browse…")
						onClicked: filePicker.open()
					}

					FileDialog {
						id: filePicker
						nameFilters: [ i18n("iCalendar (*.ics)") ]
						onAccepted: {
							var selected = ""
							if (typeof selectedFile !== "undefined" && selectedFile) {
								selected = selectedFile
							} else if (typeof fileUrl !== "undefined" && fileUrl) {
								selected = fileUrl
							}
							selected = "" + selected
							if (selected.indexOf("file://") === 0) {
								selected = selected.substr("file://".length)
								try { selected = decodeURIComponent(selected) } catch (e) {}
							}
							// Setting text in code doesn't fire onTextEdited, so save directly.
							calendarsModel.setItemProperty(index, "url", selected)
						}
					}
				}

				Kirigami.Separator {
					Layout.fillWidth: true
					visible: index < calendarsModel.count - 1
				}
			}
		}
	}
}
