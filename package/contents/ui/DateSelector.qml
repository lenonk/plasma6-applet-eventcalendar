import QtQuick 2.0
import QtQuick.Window 2.2
import QtQml

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import QtQuick.Templates 2.1 as T
import QtQuick.Controls 2.1 as Controls
import Qt5Compat.GraphicalEffects // DropShadow

// Based on:
// https://github.com/KDE/plasma-framework/blob/master/src/declarativeimports/plasmacomponents3/ComboBox.qml
// https://doc.qt.io/archives/qt-5.11/qml-qtquick-controls2-combobox.html
// https://github.com/qt/qtquickcontrols2/blob/dev/src/quicktemplates2/qquickcombobox.cpp

PlasmaComponents3.TextField {
	id: dateSelector
	readonly property Item control: dateSelector

	readonly property var units: Kirigami.Units
	readonly property var theme: PlasmaCore.Theme

	property int defaultMinimumWidth: 80
	readonly property int implicitContentWidth: contentWidth + leftPadding + rightPadding
	implicitWidth: Math.max(defaultMinimumWidth, implicitContentWidth)

	property var dateTime: new Date()
	property var dateFormat: Locale.ShortFormat

	signal dateTimeShifted(date oldDateTime, int deltaDateTime, date newDateTime)
	signal dateSelected(date newDateTime)

	function setDateTime(dt) {
		var oldDateTime = new Date(dateTime)

		var newDateTime = new Date(dt)
		newDateTime.setHours(oldDateTime.getHours())
		newDateTime.setMinutes(oldDateTime.getMinutes())

		var deltaDateTime = newDateTime.valueOf() - oldDateTime.valueOf()
		dateTimeShifted(oldDateTime, deltaDateTime, newDateTime)
	}
	function updateText() {
		text = Qt.binding(function(){
			return dateSelector.dateTime.toLocaleDateString(Qt.locale(), dateSelector.dateFormat)
		})
	}

	onPressed: popup.open()

	onDateSelected: {
		setDateTime(newDateTime)
	}

	onTextEdited: {
		var dt = Date.fromLocaleDateString(Qt.locale(), text, dateSelector.dateFormat)
		// console.log('onTextEdited', text, dt)
		if (!isNaN(dt)) {
			setDateTime(dt)
		}
	}

	onEditingFinished: updateText()
	Component.onCompleted: updateText()

	property T.Popup popup: T.Popup {
		x: control.mirrored ? control.width - width : 0
		y: control.height

		implicitWidth: contentItem.implicitWidth
		implicitHeight: contentItem.implicitHeight

		topMargin: 6
		bottomMargin: 6

		// https://github.com/KDE/plasma-framework/blob/master/src/declarativeimports/calendar/qml/MonthView.qml
		contentItem: MonthView {
			id: dateSelectorMonthView

			implicitWidth: 280
			implicitHeight: 280

			today: new Date()
			currentDate: dateSelector.dateTime
			displayedDate: dateSelector.dateTime

			showTooltips: false
			showTodaysDate: false
			headingFontLevel: 3
			headingFontScale: 1.0

			onDateClicked: {
				// console.log('onDateSelected', currentDate, '(popup.visible: ', popup.visible, ')')
				dateSelector.dateSelected(clickedDate)
				popup.close()
			}
		}

		background: Rectangle {
			anchors {
				fill: parent
				margins: -1
			}
			radius: 2
			color: theme.viewBackgroundColor
			border.color: Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.3)
			layer.enabled: true

			layer.effect: DropShadow {
				transparentBorder: true
				radius: 4
				samples: 8
				horizontalOffset: 2
				verticalOffset: 2
				color: Qt.rgba(0, 0, 0, 0.3)
			}
		}
	} // Popup
}
