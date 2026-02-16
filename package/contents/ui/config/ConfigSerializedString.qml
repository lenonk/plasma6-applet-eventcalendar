import QtQuick 2.0

QtObject {
	id: obj
	property string configKey: ''
	readonly property var configPage: {
		var p = obj.parent
		while (p) {
			if (p.__eventCalendarConfigPage) return p
			p = p.parent
		}
		return null
	}

	readonly property string configValue: configKey
		? ("" + (configPage ? configPage.getConfigValue(configKey, '') : plasmoid.configuration[configKey]))
		: ''
	property var value: null
	property var defaultValue: ({}) // Empty Map

	function serialize() {
		var s = Qt.btoa(JSON.stringify(value))
		if (configPage) {
			configPage.setConfigValue(configKey, s)
		} else {
			plasmoid.configuration[configKey] = s
		}
	}

	function deserialize() {
		value = configValue ? JSON.parse(Qt.atob(configValue)) : defaultValue
	}

	onConfigKeyChanged: deserialize()
	onConfigValueChanged: deserialize()
	onValueChanged: {
		if (value === null) {
			return // 99% of the time this is unintended
		}
		serialize()
	}
}
