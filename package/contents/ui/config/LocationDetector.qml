import QtQuick
import QtPositioning

// Loaded through a Loader so the weather page still works without qt6-positioning.
PositionSource {
	id: locationDetector
	name: "geoclue2"
	active: false
	preferredPositioningMethods: PositionSource.AllPositioningMethods

	// GeoClue authorizes clients by desktop id.
	PluginParameter { name: "desktopId"; value: "org.kde.plasmashell" }

	property bool detecting: false

	signal located(real latitude, real longitude)
	signal failed(string reason) // "access", "timeout" or "other"

	function detect() {
		detecting = true
		update(30000)
	}

	onPositionChanged: {
		if (!detecting) return
		var coord = position.coordinate
		if (position.latitudeValid && position.longitudeValid && coord.isValid) {
			detecting = false
			located(coord.latitude, coord.longitude)
		}
	}

	onSourceErrorChanged: {
		if (!detecting || sourceError === PositionSource.NoError) return
		detecting = false
		if (sourceError === PositionSource.AccessError) {
			failed("access")
		} else if (sourceError === PositionSource.UpdateTimeoutError) {
			failed("timeout")
		} else {
			failed("other")
		}
	}
}
