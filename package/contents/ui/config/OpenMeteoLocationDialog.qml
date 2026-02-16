import QtQuick 2.1
import QtQuick.Layouts 1.2
import QtQuick.Controls

import ".."
import "../lib"
import "../lib/Requests.js" as Requests

Dialog {
	id: chooseLocationDialog
	title: i18n("Select location")
	modal: true
	width: 520
	height: 600
	standardButtons: Dialog.Ok | Dialog.Cancel

	property bool loadingList: false
	property string selectedName: ""
	property real selectedLatitude: 0
	property real selectedLongitude: 0
	property int selectedRow: -1

	Logger {
		id: logger
		showDebug: plasmoid.configuration.debugging
	}

	ListModel { id: locationListModel }

	Timer {
		id: debounceApplyFilter
		interval: 400
		onTriggered: chooseLocationDialog.searchLocationList(locationNameInput.text)
	}

	ColumnLayout {
		anchors.fill: parent

		LinkText {
			text: i18n("Fetched from <a href=\"%1\">%1</a>", "https://geocoding-api.open-meteo.com/")
		}

		TextField {
			id: locationNameInput
			Layout.fillWidth: true
			text: ""
			placeholderText: i18n("Search")
			onTextChanged: debounceApplyFilter.restart()
		}

		ListView {
			id: locationListView
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.minimumHeight: 200
			clip: true
			model: locationListModel

			delegate: Rectangle {
				width: locationListView.width
				height: Math.max(nameText.implicitHeight, coordsText.implicitHeight) + 10
				color: index === chooseLocationDialog.selectedRow ? Qt.rgba(0.24, 0.49, 0.75, 0.15) : "transparent"

				RowLayout {
					anchors.fill: parent
					anchors.margins: 5
					spacing: 8

					Label {
						id: nameText
						Layout.fillWidth: true
						text: displayName
						elide: Text.ElideRight
					}
					Label {
						id: coordsText
						Layout.preferredWidth: 150
						text: latitude.toFixed(3) + ", " + longitude.toFixed(3)
						horizontalAlignment: Text.AlignRight
					}
				}

				MouseArea {
					anchors.fill: parent
					onClicked: {
						chooseLocationDialog.selectedRow = index
						chooseLocationDialog.selectedName = displayName
						chooseLocationDialog.selectedLatitude = latitude
						chooseLocationDialog.selectedLongitude = longitude
					}
				}
			}

			BusyIndicator {
				anchors.centerIn: parent
				running: visible
				visible: chooseLocationDialog.loadingList
			}
		}
	}

	function clearLocationList() {
		locationListModel.clear()
		selectedRow = -1
		selectedName = ""
		selectedLatitude = 0
		selectedLongitude = 0
	}

	function parseLocationList(data) {
		var results = data && data.results ? data.results : []
		for (var i = 0; i < results.length; i++) {
			var item = results[i]
			if (!item) continue

			var name = item.name || ""
			var admin1 = item.admin1 || ""
			var country = item.country || item.country_code || ""
			var parts = []
			if (name) parts.push(name)
			if (admin1) parts.push(admin1)
			if (country) parts.push(country)

			locationListModel.append({
				displayName: parts.join(", "),
				latitude: Number(item.latitude),
				longitude: Number(item.longitude),
			})
		}
	}

	function searchLocationList(q) {
		logger.debug("searchLocationList", q)
		clearLocationList()
		if (!q) {
			return
		}

		loadingList = true
		fetchLocationList({ q: q }, function(err, data, xhr) {
			loadingList = false
			if (err) {
				console.log("searchLocationList.err", err, xhr && xhr.status, data)
				return
			}
			parseLocationList(data)
		})
	}

	function fetchLocationList(args, callback) {
		var localeName = Qt.locale().name || "en"
		var language = String(localeName).split("_")[0] || "en"
		var url = "https://geocoding-api.open-meteo.com/v1/search"
		url += "?name=" + encodeURIComponent(args.q)
		url += "&count=30"
		url += "&language=" + encodeURIComponent(language)
		url += "&format=json"
		Requests.getJSON(url, callback)
	}
}

