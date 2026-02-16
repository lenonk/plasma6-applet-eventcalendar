import QtQuick 2.1
import QtQuick.Layouts 1.2
import QtQuick.Controls

import ".."
import "../lib"
import "../lib/Requests.js" as Requests

Dialog {
	id: chooseCityDialog
	title: i18n("Select city")
	modal: true
	width: 500
	height: 600
	standardButtons: Dialog.Ok | Dialog.Cancel

	property bool loadingCityList: false
	property string selectedCityId: ""
	property int selectedRow: -1

	Logger {
		id: logger
		showDebug: plasmoid.configuration.debugging
	}

	ListModel { id: cityListModel }

	Timer {
		id: debouceApplyFilter
		interval: 400
		onTriggered: chooseCityDialog.searchCityList(cityNameInput.text)
	}

	ColumnLayout {
		anchors.fill: parent

		LinkText {
			text: i18n("Fetched from <a href=\"%1\">%1</a>", "https://openweathermap.org/find")
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
			model: cityListModel

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
						text: '<a href="https://openweathermap.org/city/' + cityId + '">' + i18n("Open Link") + '</a>'
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

	function clearCityList() {
		cityListModel.clear()
		selectedRow = -1
		selectedCityId = ""
	}

	function parseCityList(data) {
		for (var i = 0; i < data.list.length; i++) {
			var item = data.list[i]
			cityListModel.append({
				cityId: String(item.id),
				name: item.name + ", " + item.sys.country,
			})
		}
	}

	function searchCityList(q) {
		logger.debug("searchCityList", q)
		clearCityList()
		if (!q) {
			return
		}

		loadingCityList = true
		fetchCityList({
			appId: plasmoid.configuration.openWeatherMapAppId,
			q: q,
		}, function(err, data, xhr) {
			loadingCityList = false
			if (err) {
				console.log("searchCityList.err", err, xhr && xhr.status, data)
				return
			}
			parseCityList(data)
		})
	}

	function fetchCityList(args, callback) {
		if (!args.appId) {
			return callback("OpenWeatherMap AppId not set")
		}

		var url = "https://api.openweathermap.org/data/2.5/"
		url += "find?q=" + encodeURIComponent(args.q)
		url += "&type=like"
		url += "&sort=population"
		url += "&cnt=30"
		url += "&appid=" + args.appId
		Requests.getJSON(url, callback)
	}
}
