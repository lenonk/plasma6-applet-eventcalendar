import QtQuick 2.1
import QtQuick.Layouts 1.2
import QtQuick.Controls

import "../lib/Requests.js" as Requests
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
	property string selectedCityId: ""
	property int selectedRow: -1

	ListModel { id: cityListModel }
	ListModel { id: filteredCityListModel }

	Timer {
		id: debouceApplyFilter
		interval: 300
		onTriggered: applyCityFilter()
	}

	ColumnLayout {
		anchors.fill: parent

		LinkText {
			text: i18n("Fetched from <a href=\"%1\">%1</a>", "https://weather.gc.ca/canada_e.html")
		}

		ComboBox {
			id: provinceCombo
			Layout.fillWidth: true
			model: ["AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT"]
			onCurrentIndexChanged: loadProvinceCityList()
		}

		TextField {
			id: cityNameInput
			Layout.fillWidth: true
			text: ""
			placeholderText: i18n("Search")
			onTextChanged: debouceApplyFilter.restart()
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
						text: '<a href="https://weather.gc.ca/city/pages/' + cityId + '_metric_e.html">' + i18n("Open Link") + '</a>'
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
			loadProvinceCityList()
		}
	}

	function applyCityFilter() {
		var q = cityNameInput.text.toLowerCase().trim()
		filteredCityListModel.clear()
		selectedRow = -1
		selectedCityId = ""
		for (var i = 0; i < cityListModel.count; i++) {
			var item = cityListModel.get(i)
			if (!q || item.name.toLowerCase().indexOf(q) >= 0) {
				filteredCityListModel.append(item)
			}
		}
	}

	function loadCityList(provinceUrl) {
		loadingCityList = true
		cityListModel.clear()
		filteredCityListModel.clear()
		selectedRow = -1
		selectedCityId = ""

		Requests.request(provinceUrl, function(err, data) {
			loadingCityList = false
			if (err) {
				console.log("[eventcalendar]", "loadCityList.err", err, data)
				return
			}

			var cityList = WeatherCanada.parseProvincePage(data)
			for (var i = 0; i < cityList.length; i++) {
				cityListModel.append({
					cityId: cityList[i].id,
					name: cityList[i].name,
				})
			}
			cityListLoaded = true
			applyCityFilter()
		})
	}

	function loadProvinceCityList() {
		var provinceId = provinceCombo.currentText || "AB"
		var provinceUrl = "https://weather.gc.ca/forecast/canada/index_e.html?id=" + provinceId
		loadCityList(provinceUrl)
	}
}
