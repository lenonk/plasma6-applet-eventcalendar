// Version 6

import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Layouts 1.0
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

RowLayout {
	id: configColor
	spacing: Kirigami.Units.smallSpacing
	Layout.fillWidth: true
	Layout.maximumWidth: 300

	property alias label: label.text
	property alias labelColor: label.color
	property bool showAlphaChannel: true
	property int labelWidth: Kirigami.Units.gridUnit * 6

	property TextField textField: textField
	property ColorDialog dialog: dialog

	property string configKey: ''
	property string defaultColor: ''

	readonly property var configPage: {
		var p = configColor.parent
		while (p) {
			if (p.__eventCalendarConfigPage) return p
			p = p.parent
		}
		return null
	}

	readonly property string configValue: configKey
		? ("" + (configPage ? configPage.getConfigValue(configKey, "") : plasmoid.configuration[configKey]))
		: ""

	readonly property color defaultColorValue: defaultColor

	// Stored config string (empty string means "use default").
	property string value: ""

	readonly property color valueColor: {
		if (value === "" && defaultColor) {
			return defaultColorValue
		}
		return value
	}

	readonly property color buttonOutlineColor: {
		if (valueColor.r + valueColor.g + valueColor.b > 0.5) {
			return "#BB000000" // Black outline
		}
		return "#BBFFFFFF" // White outline
	}

	property bool __updatingFromConfig: false
	onConfigValueChanged: {
		if (textField.activeFocus) return
		if (value === configValue) return
		__updatingFromConfig = true
		value = configValue
		__updatingFromConfig = false
	}

	Component.onCompleted: {
		value = configValue
	}

	onValueChanged: {
		if (!textField.activeFocus && textField.text !== value) {
			textField.text = value
		}
		if (__updatingFromConfig) return
		if (!configKey) return

		// Store "" to mean "use the default theme color".
		var toStore = value
		var defaultStr = defaultColor ? ("" + defaultColorValue) : ""
		if (defaultStr && ("" + value) === defaultStr) {
			toStore = ""
		}

		if (configPage) {
			configPage.setConfigValue(configKey, toStore)
		} else {
			plasmoid.configuration[configKey] = toStore
		}
	}

	function setValue(newColor) {
		value = newColor
	}

	Label {
		id: label
		text: "Label"
		Layout.preferredWidth: configColor.labelWidth
		Layout.minimumWidth: configColor.labelWidth
		horizontalAlignment: Text.AlignRight
		elide: Text.ElideRight
		wrapMode: Text.NoWrap
	}

	MouseArea {
		id: mouseArea
		Layout.preferredWidth: textField.height
		Layout.preferredHeight: textField.height
		hoverEnabled: true
		onClicked: dialog.open()

		Rectangle {
			anchors.fill: parent
			color: configColor.valueColor
			border.width: 2
			border.color: parent.containsMouse ? Kirigami.Theme.highlightColor : buttonOutlineColor
		}
	}

	TextField {
		id: textField
		placeholderText: defaultColor ? defaultColor : "#AARRGGBB"
		Layout.fillWidth: true
		onTextChanged: {
			// Only apply valid formats:
			//   Empty (use default)
			//   or #RGB or #RRGGBB or #AARRGGBB
			if (text.length === 0
				|| (text.indexOf('#') === 0 && (text.length === 4 || text.length === 7 || text.length === 9))
			) {
				configColor.value = text
			}
		}
	}

	ColorDialog {
		id: dialog
		title: configColor.label
		selectedColor: configColor.valueColor
		onAccepted: {
			var c = null
			if (typeof selectedColor !== "undefined" && selectedColor) {
				c = selectedColor
			} else if (typeof color !== "undefined" && color) {
				c = color
			} else if (typeof currentColor !== "undefined" && currentColor) {
				c = currentColor
			}
			if (c) {
				configColor.value = "" + c
			}
		}
	}
}
