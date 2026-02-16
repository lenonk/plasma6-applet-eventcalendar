import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import ".."
import "../lib"

ConfigPage {
	id: page

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.largeSpacing

		ConfigSection {
			title: i18n("Visibility")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show agenda")
					checked: !!page.cfg_widgetShowAgenda
					onToggled: page.cfg_widgetShowAgenda = checked
				}
			}
		}

		ConfigSection {
			title: i18n("Appearance")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				RowLayout {
					Kirigami.FormData.label: i18n("Font size:")

					QQC2.SpinBox {
						id: fontSizeSpin
						from: 0
						to: 48
						value: typeof page.cfg_agendaFontSize === "number" ? page.cfg_agendaFontSize : Number(page.cfg_agendaFontSize || 0)
						onValueModified: page.cfg_agendaFontSize = value
					}

						QQC2.Label {
							Layout.alignment: Qt.AlignVCenter
							opacity: 0.8
							text: i18n("px (0 = system font)")
						}
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Day spacing:")

					QQC2.SpinBox {
						from: 0
						to: 64
						value: typeof page.cfg_agendaDaySpacing === "number" ? page.cfg_agendaDaySpacing : Number(page.cfg_agendaDaySpacing || 0)
						onValueModified: page.cfg_agendaDaySpacing = value
					}

						QQC2.Label {
							Layout.alignment: Qt.AlignVCenter
							opacity: 0.8
							text: i18n("px")
						}
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Event spacing:")

					QQC2.SpinBox {
						from: 0
						to: 64
						value: typeof page.cfg_agendaEventSpacing === "number" ? page.cfg_agendaEventSpacing : Number(page.cfg_agendaEventSpacing || 0)
						onValueModified: page.cfg_agendaEventSpacing = value
					}

						QQC2.Label {
							Layout.alignment: Qt.AlignVCenter
							opacity: 0.8
							text: i18n("px")
						}
				}
			}
		}

		ConfigSection {
			title: i18n("Weather")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show weather icon")
					checked: page.cfg_agendaWeatherShowIcon === undefined ? true : !!page.cfg_agendaWeatherShowIcon
					onToggled: page.cfg_agendaWeatherShowIcon = checked
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Icon size:")

					QQC2.Slider {
						id: iconSizeSlider
						Layout.fillWidth: true
						from: 12
						to: 48
						stepSize: 1
						value: typeof page.cfg_agendaWeatherIconHeight === "number" ? page.cfg_agendaWeatherIconHeight : Number(page.cfg_agendaWeatherIconHeight || 24)
						onMoved: page.cfg_agendaWeatherIconHeight = value
					}

						QQC2.Label {
							Layout.alignment: Qt.AlignVCenter
							opacity: 0.8
							text: Math.round(iconSizeSlider.value) + i18n("px")
						}
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Outline weather icons")
					checked: page.cfg_showOutlines === undefined ? true : !!page.cfg_showOutlines
					onToggled: page.cfg_showOutlines = checked
					enabled: !!page.cfg_agendaWeatherShowIcon
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show weather text")
					checked: page.cfg_agendaWeatherShowText === undefined ? true : !!page.cfg_agendaWeatherShowText
					onToggled: page.cfg_agendaWeatherShowText = checked
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Weather column:")

					QQC2.ComboBox {
						Layout.fillWidth: true
						textRole: "text"
						model: [
							{ value: false, text: i18n("Left") },
							{ value: true, text: i18n("Right") },
						]
						Component.onCompleted: {
							currentIndex = (!!page.cfg_agendaWeatherOnRight) ? 1 : 0
						}
						onActivated: page.cfg_agendaWeatherOnRight = model[currentIndex].value
					}
				}

					QQC2.Label {
						Kirigami.FormData.label: i18n("Click weather:")
						text: i18n("Open forecast in browser")
						opacity: 0.8
					}
			}
		}

		ConfigSection {
			title: i18n("Events")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show event description")
					checked: page.cfg_agendaShowEventDescription === undefined ? true : !!page.cfg_agendaShowEventDescription
					onToggled: page.cfg_agendaShowEventDescription = checked
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Hide “All Day” text")
					checked: !!page.cfg_agendaCondensedAllDayEvent
					onToggled: page.cfg_agendaCondensedAllDayEvent = checked
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show Google Hangouts link")
					checked: !!page.cfg_agendaShowEventHangoutLink
					onToggled: page.cfg_agendaShowEventHangoutLink = checked
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Multi-day events:")

					QQC2.ComboBox {
						Layout.fillWidth: true
						textRole: "text"
						model: [
							{ value: true, text: i18n("Show on all days") },
							{ value: false, text: i18n("Show only on first and current day") },
						]
						Component.onCompleted: currentIndex = (page.cfg_agendaBreakupMultiDayEvents === false) ? 1 : 0
						onActivated: page.cfg_agendaBreakupMultiDayEvents = model[currentIndex].value
					}
				}

					QQC2.Label {
						Kirigami.FormData.label: i18n("Click date:")
						text: i18n("Open the new event form")
						opacity: 0.8
					}

					QQC2.Label {
						Kirigami.FormData.label: i18n("Click event:")
						text: i18n("Open event in browser")
						opacity: 0.8
					}
			}
		}

		ConfigSection {
			title: i18n("New Event Form")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Remember selected calendar")
					checked: !!page.cfg_agendaNewEventRememberCalendar
					onToggled: page.cfg_agendaNewEventRememberCalendar = checked
				}
			}
		}

		AppletConfig { id: config }
		ColorGrid {
			title: i18n("Colors")

			ConfigColor {
				configKey: "agendaInProgressColor"
				label: i18n("In progress day")
				defaultColor: config.agendaInProgressColorDefault
			}
		}

		// Keep these placeholders visible (for now) so we don't silently remove UI.
		ConfigSection {
			title: i18n("Current Month (Not Implemented Yet)")

			QQC2.CheckBox {
				enabled: false
				checked: true
				text: i18n("Always show next 14 days")
			}
			QQC2.CheckBox {
				enabled: false
				checked: false
				text: i18n("Hide completed events")
			}
			QQC2.CheckBox {
				enabled: false
				checked: true
				text: i18n("Show all events of the current day (including completed events)")
			}
		}
	}
}
