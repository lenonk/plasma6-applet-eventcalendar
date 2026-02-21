import QtQuick 2.0
import QtQuick.Controls 2.2 as QQC2
import QtQuick.Layouts 1.1
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3

import "LocaleFuncs.js" as LocaleFuncs

Item {
	id: timerView

	property bool isSetTimerViewVisible: false

	implicitHeight: timerButtonView.height

	ColumnLayout {
		id: timerButtonView
		anchors.left: parent.left
		anchors.right: parent.right
		spacing: 4
		opacity: timerView.isSetTimerViewVisible ? 0 : 1
		visible: opacity > 0
			Behavior on opacity {
				NumberAnimation { duration: 200 }
			}


			RowLayout {
				id: topRow
				spacing: Kirigami.Units.largeSpacing
				property int contentsWidth: timerLabel.width + topRow.spacing + toggleButtonColumn.Layout.preferredWidth
				property bool contentsFit: timerButtonView.width >= contentsWidth

			PlasmaComponents3.ToolButton {
				id: timerLabel
				text: "0:00"
				icon.name: {
					if (timerModel.secondsLeft === 0) {
						return 'chronometer'
					} else if (timerModel.running) {
						return 'chronometer-pause'
					} else {
						return 'chronometer-start'
					}
				}
				icon.width: Kirigami.Units.iconSizes.large
				icon.height: Kirigami.Units.iconSizes.large
				font.pointSize: -1
				font.pixelSize: appletConfig.timerClockFontHeight
				Layout.alignment: Qt.AlignVCenter
				property string tooltip: {
					var s = ""
					if (timerModel.secondsLeft > 0) {
						if (timerModel.running) {
							s += i18n("Pause Timer")
						} else {
							s += i18n("Start Timer")
						}
						s += "\n"
					}
					s += i18n("Scroll to add to duration")
					return s
				}
				QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
				QQC2.ToolTip.text: tooltip
				QQC2.ToolTip.visible: hovered

				onClicked: {
					if (timerModel.running) {
						timerModel.pause()
					} else if (timerModel.secondsLeft > 0) {
						timerModel.runTimer()
					} else { // timerModel.secondsLeft == 0
						// ignore
					}
				}

				MouseArea {
					acceptedButtons: Qt.RightButton
					anchors.fill: parent

					// onClicked: contextMenu.show(mouse.x, mouse.y)
					onClicked: contextMenu.showBelow(timerLabel)
				}

					MouseArea {
						anchors.fill: parent
						acceptedButtons: Qt.MiddleButton

						onWheel: function(wheel) {
							var delta = wheel.angleDelta.y || wheel.angleDelta.x
							if (delta > 0) {
								timerModel.increaseDuration()
								timerModel.pause()
						} else if (delta < 0) {
							timerModel.decreaseDuration()
							timerModel.pause()
						}
					}
				}
			}
			
			ColumnLayout {
				id: toggleButtonColumn
				Layout.alignment: Qt.AlignBottom
				Layout.minimumWidth: sizingButton.height
				Layout.preferredWidth: sizingButton.implicitWidth

				PlasmaComponents3.ToolButton {
					id: sizingButton
					text: "Test"
					visible: false
				}
				
				PlasmaComponents3.ToolButton {
					id: timerRepeatsButton
					readonly property bool isChecked: plasmoid.configuration.timerRepeats // New property to avoid checked=pressed theming.
					icon.name: isChecked ? 'media-playlist-repeat' : 'gtk-stop'
					text: topRow.contentsFit ? i18n("Repeat") : ""
					onClicked: {
						plasmoid.configuration.timerRepeats = !isChecked
					}

					PlasmaCore.ToolTipArea {
						anchors.fill: parent
						enabled: !topRow.contentsFit
						mainText: i18n("Repeat")
						location: PlasmaCore.Types.LeftEdge
					}
				}

				PlasmaComponents3.ToolButton {
					id: timerSfxEnabledButton
					readonly property bool isChecked: plasmoid.configuration.timerSfxEnabled // New property to avoid checked=pressed theming.
					icon.name: isChecked ? 'audio-volume-high' : 'dialog-cancel'
					text: topRow.contentsFit ? i18n("Sound") : ""
					onClicked: {
						plasmoid.configuration.timerSfxEnabled = !isChecked
					}

					PlasmaCore.ToolTipArea {
						anchors.fill: parent
						enabled: !topRow.contentsFit
						mainText: i18n("Sound")
						location: PlasmaCore.Types.LeftEdge
					}
				}
			}
			
		}

				RowLayout {
					id: bottomRow
					spacing: Math.max(1, Math.round(Kirigami.Units.smallSpacing / 2))

			// onWidthChanged: console.log('row.width', width)

				Repeater {
					id: defaultTimerRepeater
					model: timerModel.defaultTimers

				TimerPresetButton {
					text: LocaleFuncs.durationShortFormat(modelData.seconds)
					onClicked: timerModel.setDurationAndStart(modelData.seconds)
					}
				}
			}
		}

	Loader {
		id: setTimerViewLoader
		anchors.fill: parent
		source: "TimerInputView.qml"
		active: timerView.isSetTimerViewVisible
		opacity: timerView.isSetTimerViewVisible ? 1 : 0
		visible: opacity > 0
		Behavior on opacity {
			NumberAnimation { duration: 200 }
		}
	}


	Component.onCompleted: {
		timerView.forceActiveFocus()
	}

	Connections {
		target: timerModel
		function onSecondsLeftChanged() {
			timerLabel.text = timerModel.formatTimer(timerModel.secondsLeft)
		}
	}


	QQC2.Menu {
		id: contextMenu
		property var dynamicItems: []

		function clearDynamicItems() {
			for (var i = 0; i < dynamicItems.length; i++) {
				dynamicItems[i].destroy()
			}
			dynamicItems = []
		}

		function addMenuAction(icon, text, handler) {
			var menuItem = Qt.createQmlObject("import QtQuick.Controls; MenuItem {}", contextMenu)
			menuItem.icon.name = icon
			menuItem.text = text
			menuItem.triggered.connect(handler)
			dynamicItems.push(menuItem)
		}

		function addMenuSeparator() {
			var separator = Qt.createQmlObject("import QtQuick.Controls; MenuSeparator {}", contextMenu)
			dynamicItems.push(separator)
		}

		function loadDynamicActions() {
			clearDynamicItems()

			// Repeat
			addMenuAction(plasmoid.configuration.timerRepeats ? "media-playlist-repeat" : "gtk-stop", i18n("Repeat"), function() {
				timerRepeatsButton.clicked()
			})

			// Sound
			addMenuAction(plasmoid.configuration.timerSfxEnabled ? "audio-volume-high" : "gtk-stop", i18n("Sound"), function() {
				timerSfxEnabledButton.clicked()
			})

			//
			addMenuSeparator()

			// Set Timer
			addMenuAction("text-field", i18n("Set Timer"), function() {
				timerView.isSetTimerViewVisible = true
			})

			//
			addMenuSeparator()

			for (var i = 0; i < timerModel.defaultTimers.length; i++) {
				var presetItem = timerModel.defaultTimers[i]
				addMenuAction("chronometer", LocaleFuncs.durationShortFormat(presetItem.seconds), timerModel.setDurationAndStart.bind(timerModel, presetItem.seconds))
			}

		}

		function show(x, y) {
			loadDynamicActions()
			contextMenu.x = x
			contextMenu.y = y
			open()
		}

		function showBelow(item) {
			loadDynamicActions()
			var p = item.mapToItem(timerView, 0, item.height)
			contextMenu.x = p.x
			contextMenu.y = p.y
			open()
		}
	}
}
