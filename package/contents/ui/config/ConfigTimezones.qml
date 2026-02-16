import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

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

		selectedTimeZones: page.cfg_selectedTimeZones
		onSelectedTimeZonesChanged: page.cfg_selectedTimeZones = selectedTimeZones
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.largeSpacing

		ConfigSection {
			title: digitalclock_i18n("Time Zones")

			Kirigami.InlineMessage {
				id: messageWidget
				Layout.fillWidth: true
				visible: false
				type: Kirigami.MessageType.Warning
				text: ""
			}

			Kirigami.SearchField {
				id: filter
				Layout.fillWidth: true
				placeholderText: digitalclock_i18n("Search Time Zones")
			}

			ListView {
				id: timeZoneView
				Layout.fillWidth: true
				// Config pages are scrollable; without an explicit height the ListView collapses to 0.
				Layout.preferredHeight: Kirigami.Units.gridUnit * 18
				Layout.minimumHeight: Kirigami.Units.gridUnit * 12
				clip: true
				boundsBehavior: Flickable.StopAtBounds
				spacing: Kirigami.Units.smallSpacing

				model: DigitalClock.TimeZoneFilterProxy {
					sourceModel: timeZoneModel
					filterString: filter.text
				}

				delegate: RowLayout {
					width: timeZoneView.width
					spacing: Kirigami.Units.smallSpacing

					QQC2.Label {
						Layout.preferredWidth: Kirigami.Units.gridUnit * 7
						Layout.minimumWidth: Layout.preferredWidth
						text: model.city
						elide: Text.ElideRight
					}

					QQC2.Label {
						Layout.preferredWidth: Kirigami.Units.gridUnit * 12
						Layout.minimumWidth: Layout.preferredWidth
						opacity: 0.8
						text: model.region
						elide: Text.ElideRight
					}

					QQC2.Label {
						Layout.fillWidth: true
						opacity: 0.6
						text: model.comment
						elide: Text.ElideRight
					}

					QQC2.CheckBox {
						checked: model.checked
						onClicked: {
							if (!checked && model.region === "Local") {
								messageWidget.text = i18n("Cannot deselect Local time from the tooltip")
								messageWidget.type = Kirigami.MessageType.Warning
								messageWidget.visible = true
								checked = true
							} else {
								messageWidget.visible = false
								model.checked = checked // setData() on proxy model
							}
						}
					}
				}
			}
		}

		ConfigSection {
			title: digitalclock_i18n("Display")

				Kirigami.FormLayout {
					Layout.fillWidth: true

					QQC2.ButtonGroup { id: timezoneDisplayType }

					QQC2.RadioButton {
						Kirigami.FormData.label: digitalclock_i18n("Display time zone as:")
						text: digitalclock_i18n("Time zone city")
						QQC2.ButtonGroup.group: timezoneDisplayType
						checked: !page.cfg_displayTimezoneAsCode
						onClicked: page.cfg_displayTimezoneAsCode = false
					}

					QQC2.RadioButton {
						Kirigami.FormData.label: ""
						text: digitalclock_i18n("Time zone code")
						QQC2.ButtonGroup.group: timezoneDisplayType
						checked: !!page.cfg_displayTimezoneAsCode
						onClicked: page.cfg_displayTimezoneAsCode = true
					}
				}
		}
	}
}
