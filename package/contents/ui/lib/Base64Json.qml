import QtQuick 2.0

QtObject {
	id: obj

	property string configKey: ""
	property var defaultValue: []

	// Set by the owner: a QtObject has no `parent` to walk. Without it, writes bypass
	// cfg_* and the config dialog's Apply reverts them.
	property var configPage: null

	readonly property string configValue: configKey
		? ("" + (configPage ? configPage.getConfigValue(configKey, "") : plasmoid.configuration[configKey]))
		: ""

	property var value: null

	// Our own write echoing back: `value` is already current, and reloading it rebuilds views.
	property string _lastSerialized: ""
	onConfigValueChanged: {
		if (configValue !== _lastSerialized) {
			deserialize()
		}
	}

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
		_lastSerialized = v
		if (configPage) {
			configPage.setConfigValue(configKey, v)
		} else {
			plasmoid.configuration[configKey] = v
		}
	}
}
