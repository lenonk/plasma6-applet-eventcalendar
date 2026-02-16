// Version 3

import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Layouts 1.0

RowLayout {
	id: configSlider

	property string configKey: ""
	readonly property var configPage: {
		var p = configSlider.parent
		while (p) {
			if (p.__eventCalendarConfigPage) return p
			p = p.parent
		}
		return null
	}
	property real maximumValue: 2147483647
	property real minimumValue: 0
	property real stepSize: 1
	property bool updateValueWhileDragging: true
	property alias value: slider.value

	property alias before: labelBefore.text
	property alias after: labelAfter.text

	Layout.fillWidth: true

	Label {
		id: labelBefore
		text: ""
		visible: text
	}

	function persistValue() {
		if (!configKey) return
		if (configPage) {
			configPage.setConfigValue(configKey, slider.value)
		} else {
			plasmoid.configuration[configKey] = slider.value
		}
	}

	Slider {
		id: slider
		Layout.fillWidth: configSlider.Layout.fillWidth
		from: configSlider.minimumValue
		to: configSlider.maximumValue
		stepSize: configSlider.stepSize
		live: configSlider.updateValueWhileDragging
		value: Number(configPage ? configPage.getConfigValue(configKey, 0) : plasmoid.configuration[configKey])

		// Only persist (into cfg_) for user-driven changes.
		onMoved: {
			configSlider.persistValue()
		}
		onValueChanged: {
			// Keyboard steps don't always emit moved() consistently.
			if (!pressed && !activeFocus) return
			configSlider.persistValue()
		}
	}

	Label {
		id: labelAfter
		text: ""
		visible: text
	}
}
