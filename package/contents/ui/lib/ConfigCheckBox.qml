// Version 2

import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Layouts 1.0

CheckBox {
	id: configCheckBox

	property string configKey: ''

	readonly property var configPage: {
		var p = configCheckBox.parent
		while (p) {
			if (p.__eventCalendarConfigPage) return p
			p = p.parent
		}
		return null
	}

	checked: !!(configPage ? configPage.getConfigValue(configKey, false) : (configKey ? plasmoid.configuration[configKey] : false))
	onToggled: {
		if (!configKey) return
		if (configPage) {
			configPage.setConfigValue(configKey, checked)
		} else {
			plasmoid.configuration[configKey] = checked
		}
	}
}
