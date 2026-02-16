import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import ".."
import "../lib"

ConfigPage {
	id: page
	// showAppletVersion: true

	readonly property string localeTimeFormat: Qt.locale().timeFormat(Locale.ShortFormat)
	readonly property string localeDateFormat: Qt.locale().dateFormat(Locale.ShortFormat)
	readonly property string line1TimeFormat: ("" + (page.cfg_clockTimeFormat1 || "")).trim() || localeTimeFormat
	readonly property string line2TimeFormat: ("" + (page.cfg_clockTimeFormat2 || "")).trim() || localeDateFormat

	readonly property string timeFormat24hour: "hh:mm"
	readonly property string timeFormat12hour: "h:mm AP"

	function setMouseWheelCommands(up, down) {
		page.cfg_clockMouseWheel = "RunCommands"
		page.cfg_clockMouseWheelUp = up
		page.cfg_clockMouseWheelDown = down
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.largeSpacing

		ConfigSection {
			title: i18n("Widgets")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.Label {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					Layout.preferredWidth: 0
					wrapMode: Text.Wrap
					opacity: 0.8
					text: i18n("Show or hide optional widgets in the popup.")
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Meteogram")
					checked: page.cfg_widgetShowMeteogram === undefined ? true : !!page.cfg_widgetShowMeteogram
					onToggled: page.cfg_widgetShowMeteogram = checked
				}

				QQC2.CheckBox {
					id: widgetShowTimer
					Kirigami.FormData.label: ""
					text: i18n("Timer")
					checked: page.cfg_widgetShowTimer === undefined ? true : !!page.cfg_widgetShowTimer
					onToggled: page.cfg_widgetShowTimer = checked
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Timer sound:")

					ConfigSound {
						Layout.fillWidth: true
						sfxEnabledKey: "timerSfxEnabled"
						sfxPathKey: "timerSfxFilepath"
						sfxPathDefaultValue: "/usr/share/sounds/freedesktop/stereo/complete.oga"
						enabled: widgetShowTimer.checked
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Clock")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				RowLayout {
					Kirigami.FormData.label: i18n("Font:")

					ConfigFontFamily {
						id: clockFontFamily
						Layout.fillWidth: true
						configKey: "clockFontFamily"
					}

					QQC2.Button {
						text: i18n("Sans Serif")
						onClicked: clockFontFamily.selectValue("Sans Serif")
					}
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Fixed height:")

					ConfigSpinBox {
						configKey: "clockMaxHeight"
						minimumValue: 0
						suffix: i18n("px")
					}

					QQC2.Label {
						Layout.alignment: Qt.AlignVCenter
						opacity: 0.8
						text: i18n("(0 = scale to fit)")
					}
				}

				QQC2.Label {
					Kirigami.FormData.label: i18n("Formatting:")
					Layout.fillWidth: true
					Layout.preferredWidth: 0
					wrapMode: Text.Wrap
					opacity: 0.8
					text: i18n("Time formats use Qt’s date/time format strings.")
				}

				LinkText {
					Kirigami.FormData.label: ""
					text: "<a href=\"https://doc.qt.io/qt-6/qml-qtqml-qt.html#formatDateTime-method\">" + i18n("Time Format Documentation") + "</a>"
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Line 1:")

					QQC2.TextField {
						id: clockTimeFormat
						Layout.fillWidth: true
						placeholderText: localeTimeFormat
						text: "" + (page.cfg_clockTimeFormat1 || "")
						onTextEdited: page.cfg_clockTimeFormat1 = text
					}

					QQC2.Label {
						Layout.alignment: Qt.AlignVCenter
						opacity: 0.7
						text: Qt.formatDateTime(new Date(), page.line1TimeFormat)
					}
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Presets:")

					QQC2.Button {
						text: Qt.formatDateTime(new Date(), page.timeFormat12hour)
						onClicked: clockTimeFormat.text = page.timeFormat12hour
					}
					QQC2.Button {
						text: Qt.formatDateTime(new Date(), page.timeFormat24hour)
						onClicked: clockTimeFormat.text = page.timeFormat24hour
					}
					QQC2.Button {
						readonly property string dateFormat: Qt.locale().timeFormat(Locale.ShortFormat).replace("mm", "mm:ss")
						text: Qt.formatDateTime(new Date(), dateFormat)
						onClicked: clockTimeFormat.text = dateFormat
					}
					QQC2.Button {
						readonly property string dateFormat: "MMM d, " + Qt.locale().timeFormat(Locale.ShortFormat)
						text: Qt.formatDateTime(new Date(), dateFormat)
						onClicked: clockTimeFormat.text = dateFormat
					}
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Bold line 1")
					checked: !!page.cfg_clockLineBold1
					onToggled: page.cfg_clockLineBold1 = checked
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show line 2")
					checked: !!page.cfg_clockShowLine2
					onToggled: page.cfg_clockShowLine2 = checked
				}

				RowLayout {
					enabled: !!page.cfg_clockShowLine2
					Kirigami.FormData.label: i18n("Line 2:")

					QQC2.TextField {
						id: clockTimeFormat2
						Layout.fillWidth: true
						placeholderText: localeDateFormat
						text: "" + (page.cfg_clockTimeFormat2 || "")
						onTextEdited: page.cfg_clockTimeFormat2 = text
					}

					QQC2.Label {
						Layout.alignment: Qt.AlignVCenter
						opacity: 0.7
						text: Qt.formatDateTime(new Date(), page.line2TimeFormat)
					}
				}

				RowLayout {
					enabled: !!page.cfg_clockShowLine2
					Kirigami.FormData.label: i18n("Presets:")

					QQC2.Button {
						readonly property string dateFormat: {
							// Remove "dddd" from LongFormat, matching the digital clock behavior.
							var format = Qt.locale().dateFormat(Locale.LongFormat)
							return format.replace(/(^dddd.?\\s)|(,?\\sdddd$)/, "")
						}
						text: Qt.formatDate(new Date(), dateFormat)
						onClicked: clockTimeFormat2.text = dateFormat
					}
					QQC2.Button {
						readonly property string dateFormat: Qt.locale().dateFormat(Locale.ShortFormat)
						text: Qt.formatDate(new Date(), dateFormat)
						onClicked: clockTimeFormat2.text = dateFormat
					}
					QQC2.Button {
						readonly property string dateFormat: "MMM d"
						text: Qt.formatDate(new Date(), dateFormat)
						onClicked: clockTimeFormat2.text = dateFormat
					}
					QQC2.Button {
						readonly property string dateFormat: "dddd MMM d"
						text: Qt.formatDate(new Date(), dateFormat)
						onClicked: clockTimeFormat2.text = dateFormat
					}
				}

				QQC2.CheckBox {
					enabled: !!page.cfg_clockShowLine2
					Kirigami.FormData.label: ""
					text: i18n("Bold line 2")
					checked: !!page.cfg_clockLineBold2
					onToggled: page.cfg_clockLineBold2 = checked
				}

				RowLayout {
					enabled: !!page.cfg_clockShowLine2
					Kirigami.FormData.label: i18n("Line 2 height:")

					QQC2.Slider {
						id: line2Height
						Layout.fillWidth: true
						from: 0.3
						to: 0.7
						stepSize: 0.01
						value: typeof page.cfg_clockLine2HeightRatio === "number"
							? page.cfg_clockLine2HeightRatio
							: Number(page.cfg_clockLine2HeightRatio || 0.4)
						onMoved: page.cfg_clockLine2HeightRatio = value
					}

					QQC2.Label {
						Layout.alignment: Qt.AlignVCenter
						opacity: 0.8
						text: Math.floor(line2Height.value * 100) + "%"
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Mouse Wheel")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.Label {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					Layout.preferredWidth: 0
					wrapMode: Text.Wrap
					opacity: 0.8
					text: i18n("Scrolling the mouse wheel over the panel clock runs the commands below.")
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Scroll up:")
					QQC2.TextField {
						Layout.fillWidth: true
						text: "" + (page.cfg_clockMouseWheelUp || "")
						onTextEdited: page.cfg_clockMouseWheelUp = text
					}
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Scroll down:")
					QQC2.TextField {
						Layout.fillWidth: true
						text: "" + (page.cfg_clockMouseWheelDown || "")
						onTextEdited: page.cfg_clockMouseWheelDown = text
					}
				}

				RowLayout {
					Kirigami.FormData.label: i18n("Presets:")

					QQC2.Button {
						text: i18n("Volume (amixer)")
						onClicked: page.setMouseWheelCommands("amixer -q sset Master 10%+", "amixer -q sset Master 10%-")
					}
					QQC2.Button {
						text: i18n("Volume (qdbus)")
						onClicked: page.setMouseWheelCommands(
							"qdbus org.kde.kglobalaccel /component/kmix invokeShortcut \"increase_volume\"",
							"qdbus org.kde.kglobalaccel /component/kmix invokeShortcut \"decrease_volume\""
						)
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Desktop Widget")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Show background")
					checked: page.cfg_showBackground === undefined ? true : !!page.cfg_showBackground
					onToggled: page.cfg_showBackground = checked
				}
			}
		}

		ConfigSection {
			title: i18n("Debugging")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				Kirigami.InlineMessage {
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					type: Kirigami.MessageType.Information
					text: i18n("Debugging logs sensitive information to the system journal (plasmashell).")
				}

				QQC2.CheckBox {
					Kirigami.FormData.label: ""
					text: i18n("Enable debugging")
					checked: !!page.cfg_debugging
					onToggled: page.cfg_debugging = checked
				}
			}
		}
	}
}

