import QtQuick 2.0

QtObject {
	id: obj

	property string configKey: ""
	property var defaultValue: []

	readonly property var configPage: {
		var p = obj.parent
		while (p) {
			if (p.__eventCalendarConfigPage) return p
			p = p.parent
		}
		return null
	}

	readonly property string configValue: configKey
		? ("" + (configPage ? configPage.getConfigValue(configKey, "") : plasmoid.configuration[configKey]))
		: ""

	property var value: null

	onConfigValueChanged: deserialize()

	function deserialize() {
		if (!configValue) {
			value = defaultValue
			return
		}
		try {
			value = JSON.parse(Qt.atob(configValue))
		} catch (e) {
			console.log("[eventcalendar] Base64Json.deserialize failed for", configKey, e)
			value = defaultValue
		}
	}

	function serialize() {
		var v = Qt.btoa(JSON.stringify(value))
		if (configPage) {
			configPage.setConfigValue(configKey, v)
		} else {
			plasmoid.configuration[configKey] = v
		}
	}
}
