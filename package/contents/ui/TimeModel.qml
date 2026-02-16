import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtQml

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

Item {
	id: timeModel
	property string timezone: "Local"
	// Plasma5Support::DataSource exposes `data` as a QQmlPropertyMap, which is
	// awkward to index when the source name contains "/" (e.g. "Europe/London").
	// Store the latest data per source in a plain JS object and reassign on every
	// update so bindings react.
	property var zoneData: ({})
	property var __loggedSources: ({})

	property var currentTime: {
		var d = timeModel.zoneData[timezone]
		return (d && d["DateTime"]) ? d["DateTime"] : new Date()
	}
	property alias dataSource: dataSource

	function _asZoneList(value) {
		if (typeof value === "undefined" || value === null) {
			return []
		}
		if (Array.isArray(value)) {
			return value.slice(0)
		}
		if (typeof value === "string") {
			var s = value.trim()
			if (!s) {
				return []
			}
			// Handle both comma-separated and semicolon-separated strings.
			var sep = s.indexOf(";") !== -1 ? ";" : ","
			var parts = s.split(sep)
			var out = []
			for (var i = 0; i < parts.length; i++) {
				var p = ("" + parts[i]).trim()
				if (p) out.push(p)
			}
			return out
		}
		// QVariantList/QStringList from config can look like an array-like object in QML.
		if (typeof value.length === "number") {
			var out2 = []
			for (var j = 0; j < value.length; j++) {
				var v = value[j]
				if (typeof v === "undefined" || v === null) continue
				var tz = ("" + v).trim()
				if (tz) out2.push(tz)
			}
			return out2
		}
		return []
	}

	property var allTimezones: {
		var timezones = _asZoneList(plasmoid.configuration.selectedTimeZones)

		// De-dup and ensure Local exists.
		var seen = {}
		var out = []
		for (var i = 0; i < timezones.length; i++) {
			var tz = ("" + timezones[i]).trim()
			if (!tz || seen[tz]) continue
			seen[tz] = true
			out.push(tz)
		}
		if (!seen["Local"]) {
			out.push("Local")
		}
		return out
	}

	signal secondChanged()
	signal minuteChanged()
	signal dateChanged()
	signal loaded()

	Plasma5Support.DataSource {
		id: dataSource
		engine: "time"
		connectedSources: timeModel.allTimezones
		interval: 1000
		intervalAlignment: Plasma5Support.Types.NoAlignment
		onNewData: function(sourceName, data) {
			if (plasmoid.configuration.debugging && !timeModel.__loggedSources[sourceName]) {
				timeModel.__loggedSources[sourceName] = true
				var keys = []
				for (var k in data) keys.push(k)
				// Use warn so it shows up in journal even if debug output is filtered.
				console.warn("[eventcalendar] TimeModel.newData", sourceName, "keys:", keys.join(","))
			}

			// Copy-on-write so any bindings that read `zoneData[...]` update.
			var next = {}
			for (var k in timeModel.zoneData) {
				next[k] = timeModel.zoneData[k]
			}
			next[sourceName] = data
			timeModel.zoneData = next

			if (sourceName === 'Local') {
				timeModel.tick()
			}
		}
	}

	property bool ready: false
	property int lastMinute: -1
	property int lastDate: -1
	function tick() {
		if (!ready) {
			ready = true
			loaded()
		}
		secondChanged()
		var currentMinute = currentTime.getMinutes()
		if (currentMinute != lastMinute) {
			minuteChanged()
			var currentDate = currentTime.getDate()
			if (currentDate != lastDate) {
				dateChanged()
				lastDate = currentDate
			}
			lastMinute = currentMinute
		}
	}


	property bool testing: false
	Component.onCompleted: {
		if (testing) {
			currentTime = new Date(2016, 1, 2, 23, 59, 55)
			timeModel.loaded()
		}
	}

	Timer {
		running: testing
		repeat: true
		interval: 1000
		onTriggered: {
			currentTime.setSeconds(currentTime.getSeconds() + 1)
			timeModel.currentTimeChanged()
			timeModel.tick()
		}
	}
}
