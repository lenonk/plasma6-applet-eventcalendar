// Version 3

import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Layouts 1.0

RowLayout {
	id: configSlider

	property string configKey: ""
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

	Slider {
		id: slider
		Layout.fillWidth: configSlider.Layout.fillWidth
		from: configSlider.minimumValue
		to: configSlider.maximumValue
		stepSize: configSlider.stepSize
		live: configSlider.updateValueWhileDragging
		value: plasmoid.configuration[configKey]
		onValueChanged: serializeTimer.restart()
	}

	Label {
		id: labelAfter
		text: ""
		visible: text
	}

	Timer { // throttle
		id: serializeTimer
		interval: 300
		onTriggered: plasmoid.configuration[configKey] = value
	}
}
