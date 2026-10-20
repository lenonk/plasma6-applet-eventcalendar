import QtQuick 2.0

QtObject {
	id: obj
	property string configKey: ''
	// Set by the owner: a QtObject has no `parent` to walk. Without it, writes bypass
	// cfg_* and the config dialog's Apply reverts them.
	property var configPage: null

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

	// Loading must not write back, or opening the dialog clobbers the live config.
	property bool _loading: false
	function load() {
		_loading = true
		deserialize()
		_loading = false
	}

	onConfigKeyChanged: load()
	onConfigValueChanged: load()
	onValueChanged: {
		if (value === null || _loading) {
			return // 99% of the time this is unintended
		}
		serialize()
	}
}
