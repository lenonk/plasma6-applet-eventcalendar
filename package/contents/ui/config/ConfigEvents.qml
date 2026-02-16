import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

import "../lib"
import "../calendars/PlasmaCalendarUtils.js" as PlasmaCalendarUtils

ConfigPage {
	id: page

	PlasmaCalendar.EventPluginsManager {
		id: eventPluginsManager
	}

	// From digitalclock's configCalendar.qml
	signal configurationChanged()

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.largeSpacing

		ConfigSection {
			title: i18n("Event Sources")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Google Calendar (configured on the Google Calendar tab)")
					checked: true
					enabled: false
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("ICalendar (.ics) (configured on the ICalendar tab)")
					checked: true
					enabled: false
					visible: plasmoid.configuration.debugging
				}
			}
		}

		ConfigSection {
			title: i18n("Plasma Calendar Plugins")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				Kirigami.InlineMessage {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					type: Kirigami.MessageType.Information
					text: i18n("Tip: If you enable a Holidays calendar in Google, disable Plasma’s “Holidays” plugin to avoid duplicates.")
				}

				ColumnLayout {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					spacing: Kirigami.Units.smallSpacing

					Repeater {
						id: calendarPluginsRepeater
						model: eventPluginsManager.model

						delegate: QQC2.CheckBox {
							text: model.display
							checked: model.checked
							onClicked: {
								model.checked = checked // needed for model's setData to be called
								// The model/enabledPlugins update asynchronously; defer so we read final state.
								Qt.callLater(function() {
									page.saveConfig()
									page.configurationChanged()
								})
							}
						}
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Refresh")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				RowLayout {
					Kirigami.FormData.label: i18n("Refresh events every:")

					QQC2.SpinBox {
						from: 5
						to: 90
						value: typeof page.cfg_eventsPollInterval === "number" ? page.cfg_eventsPollInterval : Number(page.cfg_eventsPollInterval || 15)
						onValueModified: page.cfg_eventsPollInterval = value
					}

						QQC2.Label {
							Layout.alignment: Qt.AlignVCenter
							opacity: 0.8
							text: i18nc("Polling interval in minutes", "min")
						}
				}
			}
		}

		ConfigSection {
			title: i18n("Notifications")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				ConfigNotification {
					Kirigami.FormData.label: ""
					label: i18n("Event reminder")
					notificationEnabledKey: "eventReminderNotificationEnabled"
					sfxEnabledKey: "eventReminderSfxEnabled"
					sfxPathKey: "eventReminderSfxPath"
					sfxPathDefaultValue: "/usr/share/sounds/Oxygen-Im-Nudge.ogg"

					RowLayout {
						spacing: Kirigami.Units.smallSpacing
							QQC2.Label { text: i18n("Minutes before:") }
						ConfigSpinBox {
							configKey: "eventReminderMinutesBefore"
							suffix: i18nc("Polling interval in minutes", "min")
							minimumValue: 1
						}
					}
				}

				ConfigNotification {
					Kirigami.FormData.label: ""
					label: i18n("Event starting")
					notificationEnabledKey: "eventStartingNotificationEnabled"
					sfxEnabledKey: "eventStartingSfxEnabled"
					sfxPathKey: "eventStartingSfxPath"
					sfxPathDefaultValue: "/usr/share/sounds/Oxygen-Im-Nudge.ogg"
				}
			}
		}
	}

	function saveConfig() {
		// Store normalized plugin ids (eg: "astronomicalevents", "holidaysevents").
		page.cfg_enabledCalendarPlugins = PlasmaCalendarUtils.pluginPathToFilenameList(eventPluginsManager.enabledPlugins)
	}
	function loadConfig() {
		// cfg_* values may be injected after Component.onCompleted in some setups, so
		// also react to cfg_enabledCalendarPlugins changes.
		PlasmaCalendarUtils.populateEnabledPluginsByFilename(eventPluginsManager, page.cfg_enabledCalendarPlugins || [])
	}
	Component.onCompleted: loadConfig()
	onCfg_enabledCalendarPluginsChanged: loadConfig()
}
