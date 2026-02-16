/*
 * Copyright 2013  Heena Mahour <heena393@gmail.com>
 * Copyright 2013 Sebastian Kügler <sebas@kde.org>
 * Copyright 2015, 2016 Kai Uwe Broulik <kde@privat.broulik.de>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.0 as QQC2
import QtQml

import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.ksvg as KSvg

import "./badges"

Item {
	id: daysCalendar
	readonly property var units: Kirigami.Units

	signal headerClicked

	signal previous
	signal next

	signal activated(int index, var date, var item)
	signal doubleClicked(int index, var date, var item)
	// so it forwards it to the delegate which then emits activated with all the neccessary data
	signal activateHighlightedItem

	readonly property int gridColumns: showWeekNumbers ? calendarGrid.columns + 1 : calendarGrid.columns

	property alias previousLabel: previousButton.tooltip
	property alias nextLabel: nextButton.tooltip

	property int rows
	property int columns

	property bool showWeekNumbers
	property string eventBadgeType: "theme"
	property string todayStyle: "theme"

	onShowWeekNumbersChanged: canvas.requestPaint()

	// how precise date matching should be, 3 = day+month+year, 2 = month+year, 1 = just year
	property int dateMatchingPrecision

	property alias headerModel: days.model
	property alias gridModel: repeater.model

	property alias title: heading.text

	// Extra padding around the calendar grid area (below the header).
	// This shrinks the grid and leaves empty space on the left/right/bottom.
	property int gridMargin: units.smallSpacing

	// Make the weekday header row shorter than day rows (closer to the classic calendar layout).
	readonly property real headerRowScale: 0.67
	readonly property bool hasHeaderRow: daysCalendar.headerModel !== undefined && daysCalendar.headerModel !== null
	readonly property int headerRows: hasHeaderRow ? 1 : 0
	readonly property int totalRows: daysCalendar.rows + headerRows

	// Take the calendar width, subtract the inner and outer spacings and divide by number of columns (==days in week)
	readonly property int cellWidth: Math.floor((daysCalendar.width - (daysCalendar.gridMargin * 2) - (daysCalendar.columns + 1) * root.borderWidth) / (daysCalendar.columns + (showWeekNumbers ? 1 : 0)))
	// Take the calendar height, subtract the inner spacings and divide by number of rows (root.weeks + one row for day names)
	readonly property int cellHeight: {
		// Height for each day-cell row (weeks, months, etc).
		var denom = daysCalendar.rows + (hasHeaderRow ? headerRowScale : 0)
		if (denom <= 0) {
			return 0
		}
		var gridHeight = Math.max(0, daysCalendar.height - headerRow.height - daysCalendar.gridMargin)
		var usable = gridHeight - (totalRows + 1) * root.borderWidth
		if (usable < 0) {
			usable = 0
		}
		return Math.floor(usable / denom)
	}
	readonly property int headerCellHeight: hasHeaderRow ? Math.floor(cellHeight * headerRowScale) : cellHeight

	property real transformScale: 1
	property point transformOrigin: Qt.point(width / 2, height / 2)

	transform: Scale {
		xScale: daysCalendar.transformScale
		yScale: xScale
		origin.x: transformOrigin.x
		origin.y: transformOrigin.y
	}

	Behavior on scale {
		id: scaleBehavior
		ScaleAnimator {
			duration: units.longDuration
		}
	}

	QQC2.StackView.onStatusChanged: {
		if (QQC2.StackView.status === QQC2.StackView.Inactive) {
			daysCalendar.transformScale = 1
			daysCalendar.opacity = 1
		}
	}

	RowLayout {
		id: headerRow
		anchors {
			top: parent.top
			left: parent.left
			right: parent.right
		}
		spacing: units.smallSpacing

		PlasmaExtras.Heading {
			id: heading

			Layout.fillWidth: true

			level: root.headingFontLevel
			// The default Heading scaling is a little small for the applet popup.
			// Re-implement the Heading sizing here so MonthView can apply an extra scale.
			font.pointSize: {
				var n = Kirigami.Theme.defaultFont.pointSize
				var factor = 1.0
				switch (root.headingFontLevel) {
				case 1: factor = 1.35; break;
				case 2: factor = 1.20; break;
				case 3: factor = 1.15; break;
				case 4: factor = 1.10; break;
				default: factor = 1.0; break;
				}
				return n * factor * (typeof root.headingFontScale === "number" ? root.headingFontScale : 1.0)
			}
			wrapMode: Text.NoWrap
			elide: Text.ElideRight
			font.capitalization: Font.Capitalize
			//SEE QTBUG-58307
			//try to make all heights an even number, otherwise the layout engine gets confused
			Layout.preferredHeight: implicitHeight + implicitHeight%2

			MouseArea {
				id: monthMouse
				property int previousPixelDelta

					anchors.fill: parent
					onClicked: {
						if (!stack.busy) {
							daysCalendar.headerClicked()
						}
					}
					onExited: previousPixelDelta = 0
					onWheel: function(wheel) {
						var delta = wheel.angleDelta.y || wheel.angleDelta.x
						var pixelDelta = wheel.pixelDelta.y || wheel.pixelDelta.x

					// For high-precision touchpad scrolling, we get a wheel event for basically every slightest
					// finger movement. To prevent the view from suddenly ending up in the next century, we
					// cumulate all the pixel deltas until they're larger than the label and then only change
					// the month. Standard mouse wheel scrolling is unaffected since it's fine.
					if (pixelDelta) {
						if (Math.abs(previousPixelDelta) < monthMouse.height) {
							previousPixelDelta += pixelDelta
							return
						}
					}

					if (delta >= 15) {
						daysCalendar.previous()
					} else if (delta <= -15) {
						daysCalendar.next()
					}
						previousPixelDelta = 0
					}
				}
			}

		PlasmaComponents3.ToolButton {
			id: previousButton
			icon.name: "go-previous"
			onClicked: daysCalendar.previous()
			property string tooltip: ''
			QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
			QQC2.ToolTip.text: tooltip
			QQC2.ToolTip.visible: hovered
			Accessible.name: tooltip
			//SEE QTBUG-58307
			Layout.preferredHeight: implicitHeight + implicitHeight%2
		}

		PlasmaComponents3.ToolButton {
			icon.name: "go-jump-today"
			onClicked: root.resetToToday()
			property string tooltip: i18ndc("libplasma5", "Reset calendar to today", "Today")
			QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
			QQC2.ToolTip.text: tooltip
			QQC2.ToolTip.visible: hovered
			Accessible.name: tooltip
			Accessible.description: i18nd("libplasma5", "Reset calendar to today")
			//SEE QTBUG-58307
			Layout.preferredHeight: implicitHeight + implicitHeight%2
		}

		PlasmaComponents3.ToolButton {
			id: nextButton
			icon.name: "go-next"
			onClicked: daysCalendar.next()
			property string tooltip: ''
			QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
			QQC2.ToolTip.text: tooltip
			QQC2.ToolTip.visible: hovered
			Accessible.name: tooltip
			//SEE QTBUG-58307
			Layout.preferredHeight: implicitHeight + implicitHeight%2
		}
	}

	// Paints the inner grid and the outer frame
	Canvas {
		id: canvas

		anchors {
			horizontalCenter: parent.horizontalCenter
			bottom: parent.bottom
			bottomMargin: daysCalendar.gridMargin
		}
		width: (daysCalendar.cellWidth + root.borderWidth) * gridColumns + root.borderWidth
		height: (hasHeaderRow ? daysCalendar.headerCellHeight : 0)
			+ (daysCalendar.cellHeight * daysCalendar.rows)
			+ (daysCalendar.totalRows + 1) * root.borderWidth

		opacity: root.borderOpacity
		antialiasing: false
		clip: false
		onPaint: {
			var ctx = getContext("2d");
			// this is needed as otherwise the canvas seems to have some sort of
			// inner clip region which does not update on size changes
			ctx.reset()
			ctx.save()
			ctx.clearRect(0, 0, canvas.width, canvas.height)
				ctx.strokeStyle = PlasmaCore.Theme.textColor
			ctx.lineWidth = root.borderWidth
			ctx.globalAlpha = 1.0

			ctx.beginPath()

			// When line is more wide than 1px, it is painted with 1px line at the actual coords
			// and then 1px lines are added first to the left of the middle then right (then left again)
			// So all the lines need to be offset a bit to have their middle point in the center
			// of the grid spacing rather than on the left most pixel, otherwise they will be painted
			// over the days grid which will be visible on eg. mouse hover
			var lineBasePoint = Math.floor(root.borderWidth / 2)

			// horizontal lines
			var y = lineBasePoint
			for (var i = 0; i < daysCalendar.totalRows + 1; i++) {
				var lineY = y

				if (i === 0 || i === daysCalendar.totalRows) {
					ctx.moveTo(0, lineY)
				} else {
					ctx.moveTo(showWeekNumbers ? daysCalendar.cellWidth + root.borderWidth : root.borderWidth, lineY)
				}
				ctx.lineTo(width, lineY)

				// Advance to the next line.
				if (i < daysCalendar.totalRows) {
					var rowHeight = daysCalendar.cellHeight
					if (daysCalendar.hasHeaderRow && i === 0) {
						rowHeight = daysCalendar.headerCellHeight
					}
					y += rowHeight + root.borderWidth
				}
			}

			// vertical lines
			for (var i = 0; i < gridColumns + 1; i++) {
				var lineX = lineBasePoint + (daysCalendar.cellWidth + root.borderWidth) * (i)

				// Draw the outer vertical lines in full height so that it closes
				// the outer rectangle
				if (i == 0 || i == gridColumns || !daysCalendar.hasHeaderRow) {
					ctx.moveTo(lineX, 0)
				} else {
					ctx.moveTo(lineX, root.borderWidth + daysCalendar.headerCellHeight)
				}
				ctx.lineTo(lineX, height)
			}

			ctx.closePath()
			ctx.stroke()
			ctx.restore()
		}
	}

	KSvg.Svg {
		id: calendarSvg
		imagePath: "widgets/calendar"
	}

	Component {
		id: themeBadgeComponent
		Item {
			id: themeBadge
			KSvg.SvgItem {
				id: eventsMarker
				anchors.bottom: themeBadge.bottom
				anchors.right: themeBadge.right
				height: parent.height / 3
				width: height
				svg: calendarSvg
				elementId: "event"
			}
		}
	}

	Component {
		id: highlightBarBadgeComponent
		HighlightBarBadge {}
	}

	Component {
		id: eventColorsBarBadgeComponent
		EventColorsBarBadge {}
	}

	Component {
		id: dotsBadgeComponent
		DotsBadge {}
	}

	Component {
		id: eventCountBadgeComponent
		EventCountBadge {}
	}

	Connections {
		target: PlasmaCore.Theme
		function onThemeChangedProxy() { canvas.requestPaint() }
	}

	Column {
		id: weeksColumn
		visible: showWeekNumbers
		anchors {
			top: canvas.top
			left: canvas.left
			bottom: canvas.bottom
			// The borderWidth needs to be counted twice here because it goes
			// in fact through two lines - the topmost one (the outer edge)
			// and then the one below weekday strings
			topMargin: (daysCalendar.hasHeaderRow ? daysCalendar.headerCellHeight : 0) + root.borderWidth + root.borderWidth
		}
		spacing: root.borderWidth

		Repeater {
			model: showWeekNumbers ? calendarBackend.weeksModel : []

			PlasmaComponents3.Label {
				height: daysCalendar.cellHeight
				width: daysCalendar.cellWidth
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				font.pointSize: -1 // Ignore pixelSize warning
					font.pixelSize: Math.max(PlasmaCore.Theme.smallestFont.pixelSize, Math.min(daysCalendar.cellHeight / 3, daysCalendar.cellWidth * 5/8))
				readonly property bool isCurrentWeek: root.currentMonthContainsToday && modelData == calendarBackend.currentWeek()
				readonly property bool showHighlight: isCurrentWeek && root.highlightCurrentDayWeek
					color: showHighlight ? PlasmaCore.Theme.highlightColor : PlasmaCore.Theme.textColor
				opacity: showHighlight ? 0.75 : 0.4
				text: modelData
			}
		}
	}

	Grid {
		id: calendarGrid

		anchors {
			right: canvas.right
			rightMargin: root.borderWidth
			bottom: canvas.bottom
			bottomMargin: root.borderWidth
		}

		columns: daysCalendar.columns
		rows: daysCalendar.rows + (daysCalendar.headerModel ? 1 : 0)

		spacing: root.borderWidth
		property Item selectedItem
		property bool containsEventItems: false // FIXME
		property bool containsTodoItems: false // FIXME

		property QtObject selectedDate: root.date
		onSelectedDateChanged: {
			// clear the selection if the root.date is null
			if (calendarGrid.selectedDate == null) {
				calendarGrid.selectedItem = null
			}
		}

		Repeater {
			id: days

			PlasmaComponents3.Label {
				width: daysCalendar.cellWidth
				height: daysCalendar.headerCellHeight
				font.pointSize: -1 // Ignore pixelSize warning
				// Weekday headers should be a bit smaller than day numbers.
				font.pixelSize: Math.max(PlasmaCore.Theme.smallestFont.pixelSize, Math.min(daysCalendar.cellHeight / 3.4, daysCalendar.cellWidth * 9/16))
				horizontalAlignment: Text.AlignHCenter
				// Reduce the perceived gap between weekday names and the first date row.
				verticalAlignment: Text.AlignBottom
				bottomPadding: Math.round(units.smallSpacing / 4)
				elide: Text.ElideRight
				fontSizeMode: Text.HorizontalFit
				readonly property int currentDayIndex: (calendarBackend.firstDayOfWeek + index) % 7
				readonly property bool isCurrentDay: root.currentMonthContainsToday && root.today && root.today.getDay() === currentDayIndex
				readonly property bool showHighlight: isCurrentDay && root.highlightCurrentDayWeek
					color: showHighlight ? PlasmaCore.Theme.highlightColor : PlasmaCore.Theme.textColor
				opacity: showHighlight ? 0.75 : 0.4
				text: Qt.locale().dayName(currentDayIndex, Locale.ShortFormat)
			}
		}

		Repeater {
			id: repeater

			DayDelegate {
				id: delegate
				width: daysCalendar.cellWidth
				height: daysCalendar.cellHeight

				onClicked: daysCalendar.activated(index, model, delegate)
				onDoubleClicked: daysCalendar.doubleClicked(index, model, delegate)

				eventBadgeType: {
					switch (daysCalendar.eventBadgeType) {
						case 'bottomBar':
						case 'dots':
							return daysCalendar.eventBadgeType

						case 'theme':
						default:
							if (calendarSvg.hasElement('event')) {
								return daysCalendar.eventBadgeType
							} else {
								return 'bottomBar'
							}
					}
				}

				todayStyle: {
					switch (daysCalendar.todayStyle) {
						case 'bigNumber':
							return daysCalendar.todayStyle

						case 'theme':
						default:
							return 'theme'
					}
				}

					Connections {
						target: daysCalendar
						function onActivateHighlightedItem() {
							if (delegate.containsMouse) {
								delegate.clicked(null)
							}
						}
					}
			}
		}
	}
}
