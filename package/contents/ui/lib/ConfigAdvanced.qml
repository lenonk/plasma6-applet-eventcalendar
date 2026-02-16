import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigPage {
	id: page

	readonly property bool debugEnabled: !!page.getConfigValue("debugging", false)
	readonly property bool mockPrecipEnabled: !!page.getConfigValue("weatherMockPrecipitation", false)

	function detectStringType(value) {
		if (typeof value !== "string" || !value) {
			return null
		}
		try {
			var decoded = Qt.atob(value)
			JSON.parse(decoded)
			return "base64json"
		} catch (e) {
			return null
		}
	}

	function refreshModel() {
		configTableModel.clear()
		var keys = plasmoid.configuration.keys()

		keys = keys.filter(function(key) {
			if (key && key.length >= "Default".length
				&& key.substr(key.length - "Default".length) === "Default"
			) {
				var key2 = key.substr(0, key.length - "Default".length)
				if (typeof plasmoid.configuration[key2] !== "undefined") {
					return false
				}
			}
			return true
		})
		configTableModel.keys = keys

		for (var i = 0; i < keys.length; i++) {
			var key = keys[i]
			if (key === "minimumWidth") {
				break
			}

			var value = plasmoid.configuration[key]
				configTableModel.append({
					key: key,
					valueType: typeof value,
					value: value,
					stringType: detectStringType(value),
					defaultValue: page.getConfigDefaultValue(key, undefined)
				})
			}
		}

	Component.onCompleted: refreshModel()

	ListModel {
		id: configTableModel
		dynamicRoles: true
		property var keys: []
	}

	Connections {
		target: plasmoid.configuration
		function onValueChanged(key, value) {
			var idx = configTableModel.keys.indexOf(key)
			if (idx >= 0) {
				configTableModel.setProperty(idx, "value", value)
				configTableModel.setProperty(idx, "stringType", page.detectStringType(value))
			}
		}
	}

	Component {
		id: boolEditor
		QQC2.CheckBox {
			checked: !!modelValue
			text: checked ? i18n("true") : i18n("false")
			onToggled: page.setConfigValue(modelKey, checked)
		}
	}

	Component {
		id: numberEditor
		QQC2.TextField {
			text: String(modelValue)
				onEditingFinished: {
					var n = Number(text)
					if (!isNaN(n)) {
						page.setConfigValue(modelKey, n)
					}
				}
			}
		}

	Component {
		id: stringListEditor
		QQC2.TextArea {
			text: JSON.stringify(modelValue, null, "  ")
			readOnly: true
			wrapMode: TextEdit.Wrap
			implicitHeight: Math.max(Kirigami.Units.gridUnit * 3, contentHeight + Kirigami.Units.smallSpacing)
		}
	}

	Component {
		id: stringEditor
		QQC2.TextArea {
			property bool ready: false
			text: modelValue === undefined || modelValue === null ? "" : String(modelValue)
			wrapMode: TextEdit.Wrap
			implicitHeight: Math.max(Kirigami.Units.gridUnit * 3, contentHeight + Kirigami.Units.smallSpacing)
			Component.onCompleted: ready = true
			onTextChanged: {
				if (ready) {
					page.setConfigValue(modelKey, text)
				}
			}
		}
	}

	Component {
		id: base64jsonEditor
		QQC2.TextArea {
			text: {
				if (!modelValue) {
					return ""
				}
				try {
					return JSON.stringify(JSON.parse(Qt.atob(modelValue)), null, "  ")
				} catch (e) {
					return String(modelValue)
				}
			}
			readOnly: true
			wrapMode: TextEdit.Wrap
			implicitHeight: Math.max(Kirigami.Units.gridUnit * 3, contentHeight + Kirigami.Units.smallSpacing)
		}
	}

	ColumnLayout {
		Layout.fillWidth: true
		Layout.fillHeight: true
		spacing: Kirigami.Units.largeSpacing

		Kirigami.InlineMessage {
			Layout.fillWidth: true
			type: Kirigami.MessageType.Information
			text: i18n("Developer page: inspect raw configuration keys and values. Changes are applied when you click Apply.")
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: Kirigami.Units.smallSpacing

			QQC2.Button {
				enabled: page.debugEnabled
				text: page.mockPrecipEnabled ? i18n("Disable Mock Precipitation") : i18n("Enable Mock Precipitation")
				onClicked: page.setConfigValue("weatherMockPrecipitation", !page.mockPrecipEnabled)
			}

			QQC2.Label {
				Layout.fillWidth: true
				opacity: 0.8
				text: !page.debugEnabled
					? i18n("Enable Debug mode in General to use mock precipitation controls.")
					: page.mockPrecipEnabled
					? i18n("Mock precipitation is ON (meteogram only).")
					: i18n("Mock precipitation is OFF.")
			}

			QQC2.Button {
				text: i18n("Refresh Keys")
				onClicked: page.refreshModel()
			}
		}

			QQC2.ScrollView {
				Layout.fillWidth: true
				Layout.fillHeight: true

			ListView {
				id: configTable
				spacing: Kirigami.Units.smallSpacing
				model: configTableModel
				cacheBuffer: 100000

				delegate: RowLayout {
					width: ListView.view ? ListView.view.width : 0
					spacing: Kirigami.Units.smallSpacing

					function valueToString(val) {
						return (typeof val === "undefined" || val === null) ? "" : String(val)
					}

					readonly property var configDefaultValue: page.getConfigDefaultValue(model.key, undefined)
					readonly property bool isDefault: valueToString(model.value) === valueToString(model.defaultValue)
						|| valueToString(model.value) === valueToString(configDefaultValue)

					QQC2.TextField {
						Layout.alignment: Qt.AlignTop
						Layout.preferredWidth: 220
						readOnly: true
						text: model.key
						font.bold: !isDefault
					}

					QQC2.TextField {
						Layout.alignment: Qt.AlignTop
						Layout.preferredWidth: 90
						readOnly: true
						text: model.stringType || model.valueType
					}

					Loader {
						Layout.fillWidth: true
						property var modelKey: model.key
						property var modelValue: model.value
						property var modelValueType: model.valueType
						property var modelStringType: model.stringType

						sourceComponent: {
							if (modelValueType === "boolean") {
								return boolEditor
							}
							if (modelValueType === "number") {
								return numberEditor
							}
							if (modelValueType === "object") {
								return stringListEditor
							}
							if (modelStringType === "base64json") {
								return base64jsonEditor
							}
							return stringEditor
						}
					}
				}
			}
		}
	}
}
