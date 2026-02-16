import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import ".."
import "../lib"

ConfigPage {
	id: page

	readonly property string selectedService: "" + (page.cfg_weatherService || "OpenMeteo")
	property bool showCoordinates: false

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.largeSpacing

		ConfigSection {
			title: i18n("Provider")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				RowLayout {
					Kirigami.FormData.label: i18n("Service:")

					QQC2.ComboBox {
						id: weatherServiceCombo
						Layout.fillWidth: true
						textRole: "text"
						model: [
							{ value: "OpenMeteo", text: "Open-Meteo" },
							{ value: "WeatherCanada", text: i18n("Weather Canada") },
						]

						property bool __syncing: false
						function syncFromCfg() {
							__syncing = true
							var v = "" + (page.cfg_weatherService || "OpenMeteo")
							currentIndex = (v === "WeatherCanada") ? 1 : 0
							__syncing = false
						}

						Component.onCompleted: syncFromCfg()
						onActivated: {
							if (__syncing) return
							page.cfg_weatherService = model[currentIndex].value
						}

						Connections {
							target: page
							function onCfg_weatherServiceChanged() {
								if (!weatherServiceCombo.activeFocus) {
									weatherServiceCombo.syncFromCfg()
								}
							}
						}
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Location")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				RowLayout {
					visible: page.selectedService === "OpenMeteo"
					Kirigami.FormData.label: i18n("Place:")

					QQC2.TextField {
						id: openMeteoLocationName
						Layout.fillWidth: true
						readOnly: true
						placeholderText: i18n("Search for a city")
						text: "" + (page.cfg_openMeteoLocationName || "")
					}

					QQC2.Button {
						text: i18n("Search…")
						onClicked: openMeteoLocationDialog.open()
					}

					OpenMeteoLocationDialog {
						id: openMeteoLocationDialog
						onAccepted: {
							// Update cfg_ values so Apply/Cancel works correctly.
							page.cfg_openMeteoLocationName = selectedName
							page.cfg_openMeteoLatitude = selectedLatitude
							page.cfg_openMeteoLongitude = selectedLongitude
						}
					}
				}

				QQC2.CheckBox {
					visible: page.selectedService === "OpenMeteo"
					Kirigami.FormData.label: ""
					text: i18n("Show coordinates")
					checked: page.showCoordinates
					onToggled: page.showCoordinates = checked
				}

				RowLayout {
					visible: page.selectedService === "OpenMeteo" && page.showCoordinates
					Kirigami.FormData.label: i18n("Latitude:")

					ConfigSpinBox {
						configKey: "openMeteoLatitude"
						decimals: 5
						minimumValue: -90
						maximumValue: 90
						stepSize: 0.01
					}
				}

				RowLayout {
					visible: page.selectedService === "OpenMeteo" && page.showCoordinates
					Kirigami.FormData.label: i18n("Longitude:")

					ConfigSpinBox {
						configKey: "openMeteoLongitude"
						decimals: 5
						minimumValue: -180
						maximumValue: 180
						stepSize: 0.01
					}
				}

				RowLayout {
					visible: page.selectedService === "WeatherCanada"
					Kirigami.FormData.label: i18n("City ID:")

					ConfigString {
						id: weatherCanadaCityId
						configKey: "weatherCanadaCityId"
						placeholderText: i18n("Eg: on-14")
					}

					QQC2.Button {
						text: i18n("Find…")
						onClicked: weatherCanadaCityDialog.open()
					}

					WeatherCanadaCityDialog {
						id: weatherCanadaCityDialog
						onAccepted: {
							weatherCanadaCityId.value = selectedCityId
						}
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Units")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				RowLayout {
					Kirigami.FormData.label: i18n("Temperature:")

					QQC2.ComboBox {
						id: unitsCombo
						Layout.fillWidth: true
						textRole: "text"
						model: [
							{ value: "metric", text: i18n("Celsius") },
							{ value: "imperial", text: i18n("Fahrenheit") },
							{ value: "kelvin", text: i18n("Kelvin") },
						]

						property bool __syncing: false
						function syncFromCfg() {
							__syncing = true
							var v = "" + (page.cfg_weatherUnits || "metric")
							var idx = 0
							for (var i = 0; i < model.length; i++) {
								if (model[i].value === v) idx = i
							}
							currentIndex = idx
							__syncing = false
						}

						Component.onCompleted: syncFromCfg()
						onActivated: {
							if (__syncing) return
							page.cfg_weatherUnits = model[currentIndex].value
						}

						Connections {
							target: page
							function onCfg_weatherUnitsChanged() {
								if (!unitsCombo.activeFocus) {
									unitsCombo.syncFromCfg()
								}
							}
						}
					}
				}
			}
		}

		ConfigSection {
			title: i18n("Meteogram")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				RowLayout {
					Kirigami.FormData.label: i18n("Show next:")

					QQC2.SpinBox {
						id: meteogramHoursSpin
						from: 9
						to: 48
						stepSize: 3
						value: typeof page.cfg_meteogramHours === "number" ? page.cfg_meteogramHours : Number(page.cfg_meteogramHours || 24)
						onValueModified: page.cfg_meteogramHours = value
					}

						QQC2.Label {
							Layout.alignment: Qt.AlignVCenter
							opacity: 0.8
							text: i18np("hour", "hours", meteogramHoursSpin.value)
						}
				}
			}
		}

		ConfigSection {
			title: i18n("Update")

			Kirigami.FormLayout {
				Layout.fillWidth: true

				RowLayout {
					Kirigami.FormData.label: i18n("Update forecast every:")

					QQC2.SpinBox {
						enabled: false
						from: 60
						to: 90
						value: 60
					}

						QQC2.Label {
							Layout.alignment: Qt.AlignVCenter
							opacity: 0.8
							text: i18nc("Polling interval in minutes", "min")
						}
				}
			}
		}

			AppletConfig { id: config }
			ColorGrid {
				title: i18n("Colors")

				ConfigColor {
					configKey: "meteogramTextColor"
					label: i18n("Text")
				defaultColor: config.meteogramTextColorDefault
			}
			ConfigColor {
				configKey: "meteogramGridColor"
				label: i18n("Grid")
				defaultColor: config.meteogramScaleColorDefault
			}
			ConfigColor {
				configKey: "meteogramRainColor"
				label: i18n("Rain")
				defaultColor: config.meteogramPrecipitationRawColorDefault
			}
			ConfigColor {
				configKey: "meteogramPositiveTempColor"
				label: i18n("Positive temp")
				defaultColor: config.meteogramPositiveTempColorDefault
			}
			ConfigColor {
				configKey: "meteogramNegativeTempColor"
				label: i18n("Negative temp")
				defaultColor: config.meteogramNegativeTempColorDefault
			}
			ConfigColor {
				configKey: "meteogramIconColor"
				label: i18n("Icons")
				defaultColor: config.meteogramIconColorDefault
			}
		}
	}
}
