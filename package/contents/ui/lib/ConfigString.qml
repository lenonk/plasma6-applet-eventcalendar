// Version 2

import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Layouts 1.0

TextField {
	id: configString
	Layout.fillWidth: true

	property string configKey: ''
	property alias value: configString.text
	readonly property var configPage: {
		var p = configString.parent
		while (p) {
			if (p.__eventCalendarConfigPage) return p
			p = p.parent
		}
		return null
	}

	readonly property string configValue: configKey
		? ("" + (configPage ? configPage.getConfigValue(configKey, "") : plasmoid.configuration[configKey]))
		: ""

	property bool __updatingFromConfig: false
	onConfigValueChanged: {
		if (!configString.focus && value != configValue) {
			__updatingFromConfig = true
			value = configValue
			__updatingFromConfig = false
		}
	}
	property string defaultValue: ""

	text: configString.configValue
	onTextChanged: {
		if (__updatingFromConfig) return
		if (!configKey) return
		if (configPage) {
			configPage.setConfigValue(configKey, value)
		} else {
			plasmoid.configuration[configKey] = value
		}
	}

	ToolButton {
		icon.name: "edit-clear"
		onClicked: configString.value = defaultValue

		anchors.top: parent.top
		anchors.right: parent.right
		anchors.bottom: parent.bottom

		width: height
	}
}
