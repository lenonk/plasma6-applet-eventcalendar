import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../lib"

ConfigPage {
	id: page

	function indexOfValue(model, value, valueRole) {
		for (var i = 0; i < model.length; i++) {
			if (model[i][valueRole] === value) return i
		}
		return -1
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.largeSpacing

		ConfigSection {
			title: i18n("Visibility")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show calendar")
					checked: !!page.cfg_widgetShowCalendar
					onToggled: page.cfg_widgetShowCalendar = checked
				}
			}
		}

		ConfigSection {
			title: i18n("Interaction")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.Label {
					Kirigami.FormData.label: i18n("Click a date:")
					text: i18n("Scroll to that day in the agenda")
					opacity: 0.8
				}

					RowLayout {
						id: doubleClickRow
						Kirigami.FormData.label: i18n("Double-click a date:")

						readonly property var options: [
							{ value: "GoogleCalWeb", text: i18n("New Google Calendar event (web browser)") },
							{ value: "DoNothing", text: i18n("Do nothing") },
						]

					QQC2.ComboBox {
							id: doubleClickCombo
							Layout.fillWidth: true
							textRole: "text"
							model: doubleClickRow.options

							property bool __syncing: false
							function syncFromCfg() {
								__syncing = true
								var v = ("" + (page.cfg_monthDayDoubleClick || "GoogleCalWeb"))
								var idx = page.indexOfValue(doubleClickRow.options, v, "value")
								currentIndex = idx >= 0 ? idx : 0
								__syncing = false
							}

						Component.onCompleted: syncFromCfg()
							onActivated: {
								if (__syncing) return
								page.cfg_monthDayDoubleClick = doubleClickRow.options[currentIndex].value
							}

						Connections {
							target: page
							function onCfg_monthDayDoubleClickChanged() {
								if (!doubleClickCombo.activeFocus) {
									doubleClickCombo.syncFromCfg()
								}
							}
						}
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Appearance")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				RowLayout {
					Kirigami.FormData.label: i18n("Month title format:")

					QQC2.TextField {
						id: monthTitleFormat
						Layout.fillWidth: true
						placeholderText: i18nc("calendar title format for current month", "MMMM d, yyyy")
						text: "" + (page.cfg_monthCurrentCustomTitleFormat || "")
						onTextEdited: page.cfg_monthCurrentCustomTitleFormat = text
					}

					QQC2.Label {
						Layout.alignment: Qt.AlignVCenter
						opacity: 0.7
						text: Qt.formatDateTime(new Date(), monthTitleFormat.text || monthTitleFormat.placeholderText)
					}
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show borders")
					checked: !!page.cfg_monthShowBorder
					onToggled: page.cfg_monthShowBorder = checked
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show week numbers")
					checked: !!page.cfg_monthShowWeekNumbers
					onToggled: page.cfg_monthShowWeekNumbers = checked
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Highlight current day and week")
					checked: page.cfg_monthHighlightCurrentDayWeek === undefined ? true : !!page.cfg_monthHighlightCurrentDayWeek
					onToggled: page.cfg_monthHighlightCurrentDayWeek = checked
				}

				RowLayout {
					Kirigami.FormData.label: i18n("First day of week:")

					QQC2.ComboBox {
						id: firstDayOfWeekCombo
						Layout.fillWidth: true
						model: ListModel {}
						textRole: "text"
						property bool __syncing: false

						function syncFromCfg() {
							__syncing = true
							// The firstDayOfWeek enum starts at -1 instead of 0
							var v = (typeof page.cfg_firstDayOfWeek === "number") ? page.cfg_firstDayOfWeek : -1
							currentIndex = v + 1
							__syncing = false
						}

						Component.onCompleted: {
							model.append({ text: i18n("Default"), value: -1 })
							for (var i = 0; i < 7; i++) {
								model.append({ text: Qt.locale().dayName(i), value: i })
							}
							syncFromCfg()
						}

						onActivated: {
							if (__syncing) return
							page.cfg_firstDayOfWeek = currentIndex - 1
						}

						Connections {
							target: page
							function onCfg_firstDayOfWeekChanged() {
								if (!firstDayOfWeekCombo.activeFocus) {
									firstDayOfWeekCombo.syncFromCfg()
								}
							}
						}
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Highlights & Badges")

			Kirigami.FormLayout {
				Layout.fillWidth: true

					RowLayout {
						id: badgeRow
						Kirigami.FormData.label: i18n("Event indicators:")

						readonly property var options: [
							{ value: "theme", text: i18n("Theme") },
							{ value: "dots", text: i18n("Dots (max 3)") },
						{ value: "bottomBar", text: i18n("Bottom bar (event color)") },
						{ value: "bottomBarHighlight", text: i18n("Bottom bar (highlight)") },
						{ value: "count", text: i18n("Count") },
					]

						QQC2.ComboBox {
							id: badgeCombo
							Layout.fillWidth: true
							textRole: "text"
							model: badgeRow.options
							property bool __syncing: false

							function syncFromCfg() {
								__syncing = true
								var v = "" + (page.cfg_monthEventBadgeType || "theme")
								var idx = page.indexOfValue(badgeRow.options, v, "value")
								currentIndex = idx >= 0 ? idx : 0
								__syncing = false
							}

						Component.onCompleted: syncFromCfg()
							onActivated: {
								if (__syncing) return
								page.cfg_monthEventBadgeType = badgeRow.options[currentIndex].value
							}

						Connections {
							target: page
							function onCfg_monthEventBadgeTypeChanged() {
								if (!badgeCombo.activeFocus) {
									badgeCombo.syncFromCfg()
								}
							}
						}
					}
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Highlight corner radius:")

					QQC2.Slider {
						id: radiusSlider
						Layout.fillWidth: true
						from: 0
						to: 1
						stepSize: 0.01
						value: typeof page.cfg_monthCellRadius === "number" ? page.cfg_monthCellRadius : Number(page.cfg_monthCellRadius || 0)
						onMoved: page.cfg_monthCellRadius = value
					}

					QQC2.Label {
						Layout.alignment: Qt.AlignVCenter
						opacity: 0.8
						text: Math.round(radiusSlider.value * 100) + "%"
					}
				}

					RowLayout {
						id: todayRow
						Kirigami.FormData.label: i18n("Today style:")

						readonly property var options: [
							{ value: "theme", text: i18n("Solid color (inverted)") },
							{ value: "bigNumber", text: i18n("Big number") },
					]

						QQC2.ComboBox {
							id: todayCombo
							Layout.fillWidth: true
							textRole: "text"
							model: todayRow.options
							property bool __syncing: false

							function syncFromCfg() {
								__syncing = true
								var v = "" + (page.cfg_monthTodayStyle || "theme")
								var idx = page.indexOfValue(todayRow.options, v, "value")
								currentIndex = idx >= 0 ? idx : 0
								__syncing = false
							}

						Component.onCompleted: syncFromCfg()
							onActivated: {
								if (__syncing) return
								page.cfg_monthTodayStyle = todayRow.options[currentIndex].value
							}

						Connections {
							target: page
							function onCfg_monthTodayStyleChanged() {
								if (!todayCombo.activeFocus) {
									todayCombo.syncFromCfg()
								}
							}
						}
					}
				}
			}
		}
	}
}
