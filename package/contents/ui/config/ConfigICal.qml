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

	function defaultLocalIcsPath() {
		var home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
		if (!home || home.length === 0) {
			return "calendar.ics"
		}
		return home + "/.local/share/plasma_org.kde.plasma.eventcalendar/calendar.ics"
	}

	Base64JsonListModel {
		id: calendarsModel
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
			addItem({
				url: page.defaultLocalIcsPath(),
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
		text: i18n("Add local or remote .ics calendars. Changes are applied when you click Apply.")
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
						onClicked: calendarsModel.setProperty(index, "show", checked)
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
							calendarUrlField.text = selected
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
