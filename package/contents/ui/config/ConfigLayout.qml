import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Layouts 1.0
import org.kde.kirigami as Kirigami
import Qt5Compat.GraphicalEffects // ColorOverlay

import ".."
import "../lib"

ConfigPage {
	id: page

	SystemPalette {
		id: syspal
	}

	ButtonGroup { id: layoutGroup }

	// UI-only toggle to reduce clutter for users who don't want to fine-tune sizes.
	property bool showAdvancedSizing: false

	Kirigami.InlineMessage {
		Layout.fillWidth: true
		type: Kirigami.MessageType.Information
		text: i18n("Choose how the agenda and calendar are arranged in the popup.")
	}

	CheckBox {
		Layout.fillWidth: true
		text: i18n("Show advanced sizing")
		checked: page.showAdvancedSizing
		onToggled: page.showAdvancedSizing = checked
	}

	ConfigSection {
		title: i18n("Two Columns")

		RadioButton {
			text: i18n("Agenda to the left of the calendar")
			ButtonGroup.group: layoutGroup
			checked: !!page.cfg_twoColumns
			onClicked: page.cfg_twoColumns = true
		}

		GridLayout {
			visible: page.showAdvancedSizing && !!page.cfg_twoColumns
			Layout.fillWidth: false
			Layout.alignment: Qt.AlignHCenter
			Layout.preferredWidth: 400
			columns: 3

		//--- Row1
		ConfigDimension {
			configKey: 'leftColumnWidth'
			suffix: i18n("px")
			orientation: Qt.Horizontal
			lineColor: syspal.text
			Layout.column: 1
			Layout.row: 0
		}

		ConfigDimension {
			configKey: 'rightColumnWidth'
			suffix: i18n("px")
			orientation: Qt.Horizontal
			lineColor: syspal.text
			Layout.column: 2
			Layout.row: 0
		}

		//--- Row2
		ConfigDimension {
			configKey: 'topRowHeight'
			suffix: i18n("px")
			orientation: Qt.Vertical
			lineColor: syspal.text
			Layout.column: 0
			Layout.row: 1
		}

		//--- Row3
		ConfigDimension {
			configKey: 'bottomRowHeight'
			suffix: i18n("px")
			orientation: Qt.Vertical
			lineColor: syspal.text
			Layout.column: 0
			Layout.row: 2
		}

		//--- Center
			Item {
			Layout.column: 1
			Layout.row: 1
			Layout.columnSpan: 2
			Layout.rowSpan: 2

				implicitWidth: 300
				implicitHeight: 300

			Layout.fillWidth: true
			Layout.fillHeight: true

				Image {
					id: twoColumnsImage
					anchors.fill: parent
					source: Qt.resolvedUrl("../../images/twocolumns.svg")
					smooth: true
					visible: false
				}

				ColorOverlay {
					anchors.fill: parent
					source: twoColumnsImage
					color: Kirigami.Theme.textColor
					opacity: 0.8
				}
		}
		}
	}

	ConfigSection {
		title: i18n("Single Column")

		RadioButton {
			text: i18n("Agenda below the calendar")
			ButtonGroup.group: layoutGroup
			checked: !page.cfg_twoColumns
			onClicked: page.cfg_twoColumns = false
		}

		GridLayout {
			visible: page.showAdvancedSizing && !page.cfg_twoColumns
			Layout.fillWidth: false
			Layout.alignment: Qt.AlignHCenter
			Layout.preferredWidth: 400
			columns: 3

		//--- Row1
			Item {
				implicitWidth: 150
				Layout.fillWidth: true
				Layout.column: 0
				Layout.row: 0
			}
		ConfigDimension {
			configKey: 'leftColumnWidth'
			suffix: i18n("px")
			orientation: Qt.Horizontal
			lineColor: syspal.text
			Layout.column: 1
			Layout.row: 0
		}

		//--- Row2
		ConfigDimension {
			configKey: 'monthHeightSingleColumn'
			suffix: i18n("px")
			orientation: Qt.Vertical
			lineColor: syspal.text
			Layout.column: 2
			Layout.row: 1
		}

		//--- Row3
			Item {
				implicitHeight: 150
				Layout.column: 2
				Layout.row: 2
			}

		//--- Center
			Item {
			Layout.column: 0
			Layout.row: 1
			Layout.columnSpan: 2
			Layout.rowSpan: 2

				implicitWidth: 300
				implicitHeight: 300

			Layout.fillWidth: true
			Layout.fillHeight: true

				Image {
					id: singleColumnImage
					anchors.fill: parent
					source: Qt.resolvedUrl("../../images/singlecolumn.svg")
					smooth: true
					visible: false
				}

				ColorOverlay {
					anchors.fill: parent
					source: singleColumnImage
					color: Kirigami.Theme.textColor
					opacity: 0.8
				}
		}
	}
}
}
