// Version 4

import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Layouts 1.0

RowLayout {
	id: configSpinBox

	property string configKey: ""
	readonly property var configValue: configKey ? plasmoid.configuration[configKey] : 0

	property int decimals: 0
	property int horizontalAlignment: TextInput.AlignLeft
	property real maximumValue: 2147483647
	property real minimumValue: 0
	property string prefix: ""
	property real stepSize: 1
	property string suffix: ""
	property real value: spinBox.value / scaleFactor

	readonly property real scaleFactor: Math.pow(10, Math.max(0, decimals))

	property alias before: labelBefore.text
	property alias after: labelAfter.text

	Label {
		id: labelBefore
		text: ""
		visible: text
	}

	SpinBox {
		id: spinBox
		editable: true
		from: Math.round(configSpinBox.minimumValue * configSpinBox.scaleFactor)
		to: Math.round(configSpinBox.maximumValue * configSpinBox.scaleFactor)
		stepSize: Math.max(1, Math.round(configSpinBox.stepSize * configSpinBox.scaleFactor))
		value: Math.round(configSpinBox.configValue * configSpinBox.scaleFactor)

		textFromValue: function(v, locale) {
			var numeric = v / configSpinBox.scaleFactor
			var text = configSpinBox.decimals > 0 ? numeric.toFixed(configSpinBox.decimals) : String(Math.round(numeric))
			return configSpinBox.prefix + text + configSpinBox.suffix
		}

		valueFromText: function(text, locale) {
			var s = text
			if (configSpinBox.prefix && s.indexOf(configSpinBox.prefix) === 0) {
				s = s.slice(configSpinBox.prefix.length)
			}
			if (configSpinBox.suffix && s.endsWith(configSpinBox.suffix)) {
				s = s.slice(0, s.length - configSpinBox.suffix.length)
			}
			var n = Number(s.trim())
			if (Number.isNaN(n)) {
				n = configSpinBox.minimumValue
			}
			n = Math.min(configSpinBox.maximumValue, Math.max(configSpinBox.minimumValue, n))
			return Math.round(n * configSpinBox.scaleFactor)
		}

		onValueModified: serializeTimer.restart()
	}

	Label {
		id: labelAfter
		text: ""
		visible: text
	}

	Timer { // throttle
		id: serializeTimer
		interval: 300
		onTriggered: {
			if (configKey) {
				plasmoid.configuration[configKey] = configSpinBox.value
			}
		}
	}
}
