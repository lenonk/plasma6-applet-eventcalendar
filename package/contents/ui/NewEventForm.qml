import QtQuick
import QtQuick.Controls
import QtQuick.Layouts 1.1
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "NewEventTime.js" as NewEventTime

Loader {
	id: newEventForm
	active: false
	visible: active

		sourceComponent: Component {
			RowLayout {
				spacing: Kirigami.Units.smallSpacing

			PlasmaComponents3.CheckBox {
				Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
				Layout.preferredHeight: calendarSelector.implicitHeight
				enabled: false
				visible: calendarSelector.selectedIsTasklist
			}

			Rectangle {
				Layout.preferredWidth: appletConfig.eventIndicatorWidth
				Layout.fillHeight: true
				color: calendarSelector.selectedCalendar && calendarSelector.selectedCalendar.backgroundColor || Kirigami.Theme.textColor
			}

				ColumnLayout {
					id: formColumn
					Layout.fillWidth: true
					spacing: Kirigami.Units.largeSpacing

				Component.onCompleted: {
					newEventText.forceActiveFocus()
					newEventFormOpened(model, calendarSelector)
				}

				function submit() {
					var calendarEntry = calendarSelector.model[calendarSelector.currentIndex]
					var calendarId = calendarEntry.calendarId
					var text = newEventText.text
					if (!calendarId || !date || !text.trim()) {
						return
					}
					var timing = null
					if (!calendarSelector.selectedIsTasklist) {
						timing = NewEventTime.resolve(date, text, allDayCheckBox.checked, fromField.text, toField.text)
					}
					submitNewEventForm(calendarId, date, text, timing)
					newEventText.text = ''
				}

				CalendarSelector {
					id: calendarSelector
					Layout.fillWidth: true
				}

				RowLayout {
					PlasmaComponents3.TextField {
						id: newEventText
						Layout.fillWidth: true
						placeholderText: calendarSelector.selectedIsTasklist ? i18n("Eg: Call John") : i18n("Eg: 10-12 Workout")
						onAccepted: formColumn.submit()
						Keys.onEscapePressed: newEventForm.active = false
					}
				}

				// Time of a calendar event. A time typed in the text wins over these.
				// preferredWidth 0: take the width of the agenda, don't widen it.
				RowLayout {
					Layout.fillWidth: true
					Layout.preferredWidth: 0
					visible: !calendarSelector.selectedIsTasklist
					spacing: Kirigami.Units.smallSpacing

					PlasmaComponents3.CheckBox {
						id: allDayCheckBox
						text: i18n("All day")
						checked: true
					}

					PlasmaComponents3.Label {
						text: i18n("from")
						opacity: allDayCheckBox.checked ? 0.5 : 1
					}
					PlasmaComponents3.TextField {
						id: fromField
						Layout.fillWidth: true
						Layout.minimumWidth: Kirigami.Units.gridUnit * 2
						Layout.maximumWidth: Kirigami.Units.gridUnit * 4
						placeholderText: "10:00"
						opacity: allDayCheckBox.checked ? 0.5 : 1
						validator: RegularExpressionValidator { regularExpression: /\d{0,2}(:\d{0,2})?/ }
						// typing an hour switches off "all day"
						onTextEdited: if (text) allDayCheckBox.checked = false
						onAccepted: formColumn.submit()
						Keys.onEscapePressed: newEventForm.active = false
					}

					PlasmaComponents3.Label {
						text: i18n("to")
						opacity: allDayCheckBox.checked ? 0.5 : 1
					}
					PlasmaComponents3.TextField {
						id: toField
						Layout.fillWidth: true
						Layout.minimumWidth: Kirigami.Units.gridUnit * 2
						Layout.maximumWidth: Kirigami.Units.gridUnit * 4
						placeholderText: "11:00"
						opacity: allDayCheckBox.checked ? 0.5 : 1
						validator: RegularExpressionValidator { regularExpression: /\d{0,2}(:\d{0,2})?/ }
						onTextEdited: if (text) allDayCheckBox.checked = false
						onAccepted: formColumn.submit()
						Keys.onEscapePressed: newEventForm.active = false
					}

					Item { Layout.fillWidth: true }
				}

				PlasmaComponents3.Label {
					visible: calendarSelector.selectedIsTasklist
					Layout.fillWidth: true
					Layout.preferredWidth: 0
					wrapMode: Text.WordWrap
					opacity: 0.6
					font.pointSize: Kirigami.Theme.smallFont.pointSize
					text: i18n("Google Tasks only keep the day, not the time. Pick a calendar to set hours.")
				}
			}

		}
	}
}
