import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

import ".."
import "../lib"

ConfigPage {
	id: page

	readonly property string selectedService: "" + (page.cfg_weatherService || "OpenMeteo")
	property bool showCoordinates: false

	// System timezone city (e.g. "Buenos Aires"), used to pre-fill the location search.
	property string timezoneCity: ""
	Plasma5Support.DataSource {
		engine: "time"
		connectedSources: ["Local"]
		onNewData: function(sourceName, data) {
			page.timezoneCity = ("" + (data["Timezone City"] || "")).replace(/_/g, " ")
			disconnectSource(sourceName)
		}
	}

	function openLocationSearch() {
		if (!page.cfg_openMeteoLocationName && !openMeteoLocationDialog.searchText && page.timezoneCity) {
			openMeteoLocationDialog.selectFirstResult = true
			openMeteoLocationDialog.searchText = page.timezoneCity
		}
		openMeteoLocationDialog.open()
	}

	//--- Detect location (GeoClue via QtPositioning, loaded on first use)
	property string detectStatus: ""
	property bool detecting: false
	function detectLocation() {
		page.detecting = true
		page.detectStatus = i18n("Detecting location…")
		if (locationDetectorLoader.status === Loader.Ready) {
			startDetection()
		} else {
			locationDetectorLoader.active = true // Continues in onStatusChanged
		}
	}
	function startDetection() {
		if (!locationDetectorLoader.item.valid) {
			page.detecting = false
			page.detectStatus = i18n("Location detection is unavailable. Install GeoClue and the Qt Positioning GeoClue plugin.")
			return
		}
		locationDetectorLoader.item.detect()
	}
	Loader {
		id: locationDetectorLoader
		active: false
		source: "LocationDetector.qml"
		onStatusChanged: {
			if (status === Loader.Ready) {
				page.startDetection()
			} else if (status === Loader.Error) {
				page.detecting = false
				page.detectStatus = i18n("Location detection needs the Qt Positioning module (qt6-positioning) and GeoClue.")
			}
		}
	}
	Connections {
		target: locationDetectorLoader.item
		function onLocated(latitude, longitude) {
			page.cfg_openMeteoLocationName = i18n("Current location (%1, %2)", latitude.toFixed(2), longitude.toFixed(2))
			page.cfg_openMeteoLatitude = latitude
			page.cfg_openMeteoLongitude = longitude
			page.detecting = false
			page.detectStatus = ""
		}
		function onFailed(reason) {
			page.detecting = false
			if (reason === "access") {
				page.detectStatus = i18n("Location access was denied.")
			} else if (reason === "timeout") {
				page.detectStatus = i18n("Could not determine your location in time.")
			} else {
				page.detectStatus = i18n("Could not determine your location.")
			}
		}
	}

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
						onClicked: page.openLocationSearch()
					}

					QQC2.Button {
						icon.name: "find-location"
						text: i18n("Detect")
						enabled: !page.detecting
						QQC2.ToolTip.visible: hovered
						QQC2.ToolTip.text: i18n("Uses GeoClue, which may send nearby Wi-Fi networks or your IP address to a location service.")
						onClicked: page.detectLocation()
					}

					OpenMeteoLocationDialog {
						id: openMeteoLocationDialog
						onAccepted: {
							if (selectedRow < 0) return // OK without picking a result.
							// Update cfg_ values so Apply/Cancel works correctly.
							page.cfg_openMeteoLocationName = selectedName
							page.cfg_openMeteoLatitude = selectedLatitude
							page.cfg_openMeteoLongitude = selectedLongitude
						}
					}
				}

				QQC2.Label {
					visible: page.selectedService === "OpenMeteo" && page.detectStatus !== ""
					Kirigami.FormData.label: ""
					Layout.fillWidth: true
					wrapMode: Text.Wrap
					text: page.detectStatus
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
							if (selectedCityId) {
								weatherCanadaCityId.value = selectedCityId
							}
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
