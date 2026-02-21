import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtQml
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.digitalclock as DigitalClock
import org.kde.kirigami as Kirigami
import org.kde.kirigami.primitives as KirigamiPrimitives

Item {
	id: tooltipContentItem

	property int preferredTextWidth: Kirigami.Units.gridUnit * 20

	implicitWidth: childrenRect.width + Kirigami.Units.gridUnit
	implicitHeight: childrenRect.height + Kirigami.Units.gridUnit

	LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
	LayoutMirroring.childrenInherit: true

	property var dataSource: timeModel.dataSource
	readonly property string timezoneTimeFormat: appletConfig.timeFormatShort

	function dataForZone(zone) {
		if (!timeModel || !timeModel.zoneData) {
			return null
		}
		return timeModel.zoneData[zone] || null
	}

	function timeForZone(zone) {
		var d = dataForZone(zone)
		if (!d) {
			return ""
		}

		// get the time for the given timezone from the dataengine
		var now = d["DateTime"]
		if (!now) {
			return ""
		}
		// get current UTC time
		var msUTC = now.getTime() + (now.getTimezoneOffset() * 60000)
		// add the dataengine TZ offset to it
		var offset = d["Offset"]
		var dateTime = new Date(msUTC + ((offset || 0) * 1000))

		var formattedTime = Qt.formatTime(dateTime, timezoneTimeFormat)

		var local = dataForZone("Local")
		if (local && local["DateTime"] && dateTime.getDay() != local["DateTime"].getDay()) {
			formattedTime += " (" + Qt.formatDate(dateTime, Locale.ShortFormat) + ")"
		}

		return formattedTime
	}

	function nameForZone(zone) {
		var d = dataForZone(zone)
		if (!d) return zone

		if (plasmoid.configuration.displayTimezoneAsCode) {
			return d["Timezone Abbreviation"] || zone
		} else {
			var city = d["Timezone City"]
			if (city) return city

			// Fallback: turn "Europe/London" into "London".
			var parts = ("" + zone).split("/")
			var last = parts.length ? parts[parts.length - 1] : ("" + zone)
			return last.replace(/_/g, " ")
		}
	}

	ColumnLayout {
		id: columnLayout
		anchors {
			left: parent.left
			top: parent.top
			margins: Kirigami.Units.gridUnit / 2
		}
		spacing: Kirigami.Units.largeSpacing

		RowLayout {
			spacing: Kirigami.Units.largeSpacing

			KirigamiPrimitives.Icon {
				id: tooltipIcon
				source: "preferences-system-time"
				Layout.alignment: Qt.AlignTop
				visible: true
				implicitWidth: Kirigami.Units.iconSizes.medium
				Layout.preferredWidth: implicitWidth
				Layout.preferredHeight: implicitWidth
			}

			ColumnLayout {
				spacing: 0

				PlasmaExtras.Heading {
					id: tooltipMaintext
					level: 3
					Layout.minimumWidth: Math.min(implicitWidth, preferredTextWidth)
					Layout.maximumWidth: preferredTextWidth
					elide: Text.ElideRight
					text: Qt.formatTime(timeModel.currentTime, appletConfig.timeFormatLong)
				}

				PlasmaComponents3.Label {
					id: tooltipSubtext
					Layout.minimumWidth: Math.min(implicitWidth, preferredTextWidth)
					Layout.maximumWidth: preferredTextWidth
					text: Qt.formatDate(timeModel.currentTime, Qt.locale().dateFormat(Locale.LongFormat))
					opacity: 0.6
				}
			}
		}


		GridLayout {
			id: timezoneLayout
			Layout.minimumWidth: Math.min(implicitWidth, preferredTextWidth)
			Layout.maximumWidth: preferredTextWidth
			// Layout.maximumHeight: childrenRect.height // Causes binding loop
			columns: 2
			visible: timezoneRepeater.count > 0

			Repeater {
				id: timezoneRepeater
				model: {
					// The timezones need to be duplicated in the array
					// because we need their data twice - once for the name
					// and once for the time and the Repeater delegate cannot
					// be one Item with two Labels because that wouldn't work
					// in a grid then
					var timezones = []
					var selected = timeModel.allTimezones || []
					for (var i = 0; i < selected.length; i++) {
						var timezone = selected[i]
						if (!timezone || timezone === "Local") continue
						timezones.push(timezone)
						timezones.push(timezone)
					}

					return timezones
				}

				PlasmaComponents3.Label {
					id: timezone
					// Name column (even indices) should be left-justified and prominent.
					// Time column (odd indices) keeps a lighter style.
					Layout.alignment: index % 2 === 0 ? Qt.AlignLeft : Qt.AlignRight
					Layout.fillWidth: true

					wrapMode: Text.NoWrap
					horizontalAlignment: index % 2 === 0 ? Text.AlignLeft : Text.AlignRight
					text: index % 2 == 0 ? nameForZone(modelData) : timeForZone(modelData)
					font.weight: index % 2 == 0 ? Font.Bold : Font.Normal
					elide: Text.ElideNone
					opacity: index % 2 == 0 ? 1.0 : 0.75
				}
			}
		}
	}
}
