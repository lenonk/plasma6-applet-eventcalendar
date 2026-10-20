import QtQuick 2.1
import QtQuick.Layouts 1.2
import QtQuick.Controls

import ".."
import "../weather/WeatherCanada.js" as WeatherCanada

Dialog {
	id: chooseCityDialog
	title: i18n("Select city")
	modal: true
	width: 500
	height: 600
	standardButtons: Dialog.Ok | Dialog.Cancel

	property bool loadingCityList: false
	property bool cityListLoaded: false
	property string loadError: ""
	property var allCities: []
	property string selectedCityId: ""
	property int selectedRow: -1

	ListModel { id: filteredCityListModel }

	Timer {
		id: debouceApplyFilter
		interval: 300
		onTriggered: applyCityFilter()
	}

	ColumnLayout {
		anchors.fill: parent

		LinkText {
			text: i18n("Fetched from <a href=\"%1\">%1</a>", "https://api.weather.gc.ca/")
		}

		ComboBox {
			id: provinceCombo
			Layout.fillWidth: true
			model: ["AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT"]
			onCurrentIndexChanged: applyCityFilter()
		}

		TextField {
			id: cityNameInput
			Layout.fillWidth: true
			text: ""
			placeholderText: i18n("Search")
			onTextChanged: debouceApplyFilter.restart()
		}

		Label {
			Layout.fillWidth: true
			visible: !!chooseCityDialog.loadError
			text: chooseCityDialog.loadError
			wrapMode: Text.Wrap
		}

		ListView {
			id: cityListView
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.minimumHeight: 200
			clip: true
			model: filteredCityListModel

			delegate: Rectangle {
				required property int index
				required property string cityId
				required property string name
				required property string url
				width: cityListView.width
				height: Math.max(nameText.implicitHeight, openLink.implicitHeight) + 8
				color: index === chooseCityDialog.selectedRow ? Qt.rgba(0.24, 0.49, 0.75, 0.15) : "transparent"

				RowLayout {
					anchors.fill: parent
					anchors.margins: 4
					spacing: 8

					Label {
						id: nameText
						Layout.fillWidth: true
						text: name
						elide: Text.ElideRight
					}
					Label {
						Layout.preferredWidth: 80
						text: cityId
						horizontalAlignment: Text.AlignRight
					}
					LinkText {
						id: openLink
						text: '<a href="' + url + '">' + i18n("Open Link") + '</a>'
					}
				}

				MouseArea {
					anchors.fill: parent
					onClicked: {
						chooseCityDialog.selectedRow = index
						chooseCityDialog.selectedCityId = cityId
					}
				}
			}

			BusyIndicator {
				anchors.centerIn: parent
				running: visible
				visible: chooseCityDialog.loadingCityList
			}
		}
	}

	onVisibleChanged: {
		if (visible && !cityListLoaded && !loadingCityList) {
			loadCityList()
		}
	}

	function applyCityFilter() {
		var prefix = (provinceCombo.currentText || "AB").toLowerCase() + "-"
		var q = cityNameInput.text.toLowerCase().trim()
		filteredCityListModel.clear()
		selectedRow = -1
		selectedCityId = ""
		for (var i = 0; i < allCities.length; i++) {
			var city = allCities[i]
			if (city.id.indexOf(prefix) !== 0) {
				continue
			}
			if (!q || city.name.toLowerCase().indexOf(q) >= 0) {
				filteredCityListModel.append({
					cityId: city.id,
					name: city.name,
					url: city.url,
				})
			}
		}
	}

	function loadCityList() {
		loadingCityList = true
		loadError = ""
		filteredCityListModel.clear()
		selectedRow = -1
		selectedCityId = ""

		WeatherCanada.fetchCityList(function(err, cityList) {
			loadingCityList = false
			if (err) {
				loadError = i18n("Could not load the city list: %1", "" + err)
				return
			}
			allCities = cityList
			cityListLoaded = true
			applyCityFilter()
		})
	}
}
