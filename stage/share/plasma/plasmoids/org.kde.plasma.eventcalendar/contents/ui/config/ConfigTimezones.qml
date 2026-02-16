import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Layouts 1.0

import org.kde.plasma.private.digitalclock as DigitalClock

import ".."
import "../lib"

// Mostly copied from digitalclock
ConfigPage {
	id: page

	function digitalclock_i18n(message) {
		return i18nd("plasma_applet_org.kde.plasma.digitalclock", message)
	}

	DigitalClock.TimeZoneModel {
		id: timeZoneModel

		selectedTimeZones: plasmoid.configuration.selectedTimeZones
		onSelectedTimeZonesChanged: plasmoid.configuration.selectedTimeZones = selectedTimeZones
	}

	MessageWidget {
		id: messageWidget
	}

	TextField {
		id: filter
		Layout.fillWidth: true
		placeholderText: digitalclock_i18n("Search Time Zones")
	}

	ListView {
		id: timeZoneView
		Layout.fillWidth: true
		Layout.fillHeight: true
		clip: true
		boundsBehavior: Flickable.StopAtBounds
		spacing: 2

		model: DigitalClock.TimeZoneFilterProxy {
			sourceModel: timeZoneModel
			filterString: filter.text
		}

		delegate: RowLayout {
			width: timeZoneView.width
			spacing: 8

			Label {
				Layout.fillWidth: true
				text: model.city
			}
			Label {
				Layout.fillWidth: true
				text: model.region
			}
			Label {
				Layout.fillWidth: true
				text: model.comment
			}
			CheckBox {
				checked: model.checked
				onClicked: {
					if (!checked && model.region == "Local") {
						messageWidget.warn(i18n("Cannot deselect Local time from the tooltip"))
						checked = true
					} else {
						model.checked = checked // setData() on proxy model
					}
				}
			}
		}
	}


	ButtonGroup { id: timezoneDisplayType }
	RowLayout {
		Label {
			text: digitalclock_i18n("Display time zone as:")
		}

		RadioButton {
			id: timezoneCityRadio
			text: digitalclock_i18n("Time zone city")
			ButtonGroup.group: timezoneDisplayType
			checked: !plasmoid.configuration.displayTimezoneAsCode
			onClicked: plasmoid.configuration.displayTimezoneAsCode = false
		}

		RadioButton {
			id: timezoneCodeRadio
			text: digitalclock_i18n("Time zone code")
			ButtonGroup.group: timezoneDisplayType
			checked: plasmoid.configuration.displayTimezoneAsCode
			onClicked: plasmoid.configuration.displayTimezoneAsCode = true
		}
	}
}
