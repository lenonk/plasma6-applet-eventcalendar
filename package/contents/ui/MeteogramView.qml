import QtQuick 2.0
import QtQml
import org.kde.plasma.core as PlasmaCore

import "Shared.js" as Shared
import "./weather/WeatherApi.js" as WeatherApi

Item {
	id: meteogramView
	// QtQuick.Layouts uses implicit sizes as the "natural" size. Without these,
	// the item can collapse to 0x0 if Layout hints aren't applied for any reason.
	implicitWidth: 400
	implicitHeight: 100
	property bool clock24h: appletConfig.clock24h
	property int visibleDuration: 9
	property bool showIconOutline: false
	property bool showGridlines: true
	property alias xAxisScale: graph.xAxisScale
	property int xAxisLabelEvery: 1
	property int dataPointHours: 1
	property int displayBucketHours: 3
	property alias rainUnits: graph.rainUnits
	property var lastCurrentWeatherData: null
	property var lastHourlyWeatherData: ({ list: [] })

	property bool populated: false

	onClock24hChanged: {
		graph.gridData = formatXAxisLabels(graph.gridData)
		graph.update()
	}

	onVisibleDurationChanged: {
		parseWeatherForecast(lastCurrentWeatherData, lastHourlyWeatherData)
	}

	onXAxisScaleChanged: {
		parseWeatherForecast(lastCurrentWeatherData, lastHourlyWeatherData)
	}

	Rectangle {
		visible: typeof root === 'undefined'
		color: PlasmaCore.Theme.backgroundColor
		anchors.fill: parent
	}

	Connections {
		target: appletConfig
		function onMeteogramTextColorChanged() { graph.update() }
		function onMeteogramScaleColorChanged() { graph.update() }
		function onMeteogramPositiveTempColorChanged() { graph.update() }
		function onMeteogramNegativeTempColorChanged() { graph.update() }
		function onMeteogramPrecipitationRawColorChanged() { graph.update() }
	}

	Item {
		id: graph
		anchors.fill: parent

		property int xAxisLabelHeight: 20
		property int xAxisMin: 0
		property int xAxisMax: 10
		property double xAxisScale: 0.333333333333 // 3 lines per data point
		property int yAxisLabelWidth: 30
		property int yAxisMin: -10
		property int yAxisMax: 20
		property int yAxisScale: 2
		property int yAxisScaleCount: 4
		property double yAxisRainMinScale: 2
		property double yAxisRainMax: 2
		property bool showYAxisRainMax: true
		property string rainUnits: 'mm'

		property double freezingPoint: {
			if (plasmoid.configuration.weatherUnits === "kelvin") {
				return 273.15 // https://en.wikipedia.org/wiki/Kelvin
			} else if (plasmoid.configuration.weatherUnits === "imperial") {
				return 32 // https://en.wikipedia.org/wiki/Fahrenheit
			} else { // "metric"
				return 0
			}
		}

		property int gridX: yAxisLabelWidth
		property int gridX2: width
		property int gridWidth: gridX2 - gridX
		property int gridY: 5
		property int gridY2: height - xAxisLabelHeight
		property int gridHeight: gridY2 - gridY

		property var gridData: []
		property var yData: []

		onWidthChanged: update()
		onHeightChanged: update()

		onGridDataChanged: {
			xAxisMax = Math.max(1, gridData.length - 1)

			yData = []
			var yDataMin = 0
			var yDataMax = 1
			yAxisRainMax = (rainUnits === "in") ? 0.1 : yAxisRainMinScale
			for (var i = 0; i < gridData.length; i++) {
				var y = gridData[i].y
				yData.push(y)
				if (i === 0 || y < yDataMin) {
					yDataMin = y
				}
				if (i === 0 || y > yDataMax) {
					yDataMax = y
				}
				if (rainUnits == 'mm') {
					if (gridData[i].precipitation > yAxisRainMax) {
						yAxisRainMax = Math.ceil(gridData[i].precipitation)
					}
				} else if (rainUnits == 'in') {
					if (gridData[i].precipitation > yAxisRainMax) {
						yAxisRainMax = Math.ceil(gridData[i].precipitation * 10) / 10
					}
				}
			}
			if (rainUnits === '%') {
				yAxisRainMax = 100
			}

			yAxisScale = Math.ceil((yDataMax-yDataMin) / (yAxisScaleCount))
			yAxisMin = Math.floor(yDataMin)
			yAxisMax = Math.ceil(yDataMax)
		}

		function iconsInRange(gData, s, e) {
			var out = [];
			for (var i = Math.max(0, s); i <= e && i < gData.length; i++) {
				out.push(gData[i].weatherIcon)
			}
			return out
		}

		function getAggregatedIcon(gData, s, e) {
			return WeatherApi.getMostSevereIcon(iconsInRange(gData, s, e))
		}

			function updateGridItemAreas() {
				var areas = [];
				var pointHours = Math.max(1, meteogramView.displayBucketHours || meteogramView.dataPointHours || 1)
				var iconIntervalPoints = Math.max(1, Math.round(3 / pointHours))
				var aggregationWindow = Math.max(0, Math.floor(iconIntervalPoints / 2))
				// Skip the first gridItem since it's area starts at the edge of the grid.
				for (var i = 1; i < gridData.length; i++) {
					var a = graph.gridPoint(i-2, graph.yAxisMin)
					var b = graph.gridPoint(i-1, graph.yAxisMin)
					var areaIndex = i - 1
					var area = {}
					area.areaX = a.x
					area.areaY = a.y
					area.areaWidth = b.x - a.x
					area.areaHeight = graph.gridHeight
					// console.log(JSON.stringify(area))
					area.gridItem = gridData[i]
					area.showIcon = (areaIndex % iconIntervalPoints) === 0
					if (area.showIcon) {
						area.aggregratedIcon = getAggregatedIcon(gridData, i - aggregationWindow, i + aggregationWindow)
					} else {
						area.aggregratedIcon = area.gridItem.weatherIcon
					}
					areas.push(area)
				}
			// console.log(JSON.stringify(areas))
			gridDataAreas.model = areas
		}


		function gridPoint(x, y) {
			return {
				x: (x - xAxisMin) / (xAxisMax - xAxisMin) * gridWidth + gridX,
				y: gridHeight - (y - yAxisMin) / (yAxisMax - yAxisMin) * gridHeight + gridY,
			}
		}

		function update() {
			gridCanvas.requestPaint()
			// console.log('updated')
		}

		Item {
			id: layers
			anchors.fill: parent

				Canvas {
					id: gridCanvas
					anchors.fill: parent
					canvasSize.width: parent.width
					canvasSize.height: parent.height
					contextType: '2d'

					function drawLine(ctx, x1, y1, x2, y2) {
						var p1 = graph.gridPoint(x1, y1)
						var p2 = graph.gridPoint(x2, y2)
						ctx.beginPath()
						ctx.moveTo(p1.x, p1.y)
						ctx.lineTo(p2.x, p2.y)
						ctx.stroke()
						// console.log(JSON.stringify(p1), JSON.stringify(p2))
					}

					// https://stackoverflow.com/questions/7054272/how-to-draw-smooth-curve-through-n-points-using-javascript-html5-canvas
					function drawCurve(ctx, path) {
						if (path.length < 3) return

						var gridPath = []
						for (var i = 0; i < path.length; i++) {
						var item = path[i]
						var p = graph.gridPoint(item.x, item.y)
							gridPath.push(p)
						}

						ctx.beginPath()
						ctx.moveTo(gridPath[0].x, gridPath[0].y)

						// curve from 1 .. n-2
						for (var i = 1; i < path.length - 2; i++) {
							var xc = (gridPath[i].x + gridPath[i+1].x) / 2
							var yc = (gridPath[i].y + gridPath[i+1].y) / 2
							
							ctx.quadraticCurveTo(gridPath[i].x, gridPath[i].y, xc, yc)
						}
						var n = path.length-1
						ctx.quadraticCurveTo(gridPath[n-1].x, gridPath[n-1].y, gridPath[n].x, gridPath[n].y)

						ctx.stroke()
					}

					onPaint: {
						// Qt6 no longer injects a magic `context` identifier; always use the returned ctx.
						var ctx = getContext("2d")
						if (!ctx) return

						if (typeof ctx.reset === "function") {
							ctx.reset()
						}
						ctx.clearRect(0, 0, gridCanvas.width, gridCanvas.height)

						if (graph.gridData.length < 2) return
						if (graph.yAxisMin === graph.yAxisMax) return

						// rain
						graph.showYAxisRainMax = false
						var gridDataAreaWidth = 0
						for (var i = 1; i < graph.gridData.length; i++) {
							var item = graph.gridData[i]
							// console.log(i, item, item.precipitation, graph.yAxisRainMax)
							if (item.precipitation) {
								graph.showYAxisRainMax = true
								var rainY = Math.min(item.precipitation, graph.yAxisRainMax) / graph.yAxisRainMax
								// console.log('rainY', i, rainY)
								var a = graph.gridPoint(i-1, graph.yAxisMin)
								var b = graph.gridPoint(i, graph.yAxisMin)
								var h = rainY * graph.gridHeight
								gridDataAreaWidth = b.x-a.x
								ctx.fillStyle = "" + appletConfig.meteogramPrecipitationColor
								ctx.fillRect(a.x, a.y, gridDataAreaWidth, -h)
							}
						}

						// yAxis scale
						for (var y = graph.yAxisMin; y <= graph.yAxisMax; y += graph.yAxisScale) {
							ctx.strokeStyle = "" + appletConfig.meteogramScaleColor
							ctx.lineWidth = 1
							drawLine(ctx, graph.xAxisMin, y, graph.xAxisMax, y)

							// yAxis label: temp
							var p = graph.gridPoint(graph.xAxisMin, y)
							ctx.fillStyle = "" + appletConfig.meteogramTextColor
							ctx.font = "12px sans-serif"
							ctx.textAlign = 'end'
							var labelText = y + '°'
							ctx.fillText(labelText, p.x - 2, p.y + 6)
						}

						// xAxis scale
						for (var x = graph.xAxisMin; x <= graph.xAxisMax; x += graph.xAxisScale) {
							ctx.strokeStyle = "" + appletConfig.meteogramScaleColor
							ctx.lineWidth = 1
							drawLine(ctx, x, graph.yAxisMin, x, graph.yAxisMax)
						}
						for (var i = 0; i < graph.gridData.length; i++) {
							var item = graph.gridData[i]
							var p = graph.gridPoint(i, graph.yAxisMin)

							ctx.fillStyle = "" + appletConfig.meteogramTextColor
							ctx.font = "12px sans-serif"
							ctx.textAlign = 'center'

							if (item.xLabel) {
								ctx.fillText(item.xLabel, p.x, p.y + 12 + 2)
							}
						}


						// temp
						// ctx.strokeStyle = '#900'
						ctx.lineWidth = 3
						var path = []
						var pathMinY
						var pathMaxY
						for (var i = 0; i < graph.gridData.length; i++) {
						var item = graph.gridData[i]
						path.push({ x: i, y: item.y })
						if (i === 0 || item.y < pathMinY) pathMinY = item.y
						if (i === 0 || item.y > pathMaxY) pathMaxY = item.y
					}
					
					var pZeroY = graph.gridPoint(0, graph.freezingPoint).y
					var pMaxY = graph.gridPoint(0, pathMinY).y // y axis gets flipped
					var pMinY = graph.gridPoint(0, pathMaxY).y // y axis gets flipped
					var height = pMaxY - pMinY
					var pZeroYRatio = (pZeroY-pMinY) / height
						// console.log(pMinY, pMaxY)
						// console.log(height)
						// console.log(pZeroY, pZeroYRatio)
						if (pZeroYRatio <= 0) {
							ctx.strokeStyle = "" + appletConfig.meteogramNegativeTempColor
						} else if (pZeroYRatio >= 1) {
							ctx.strokeStyle = "" + appletConfig.meteogramPositiveTempColor
						} else {
							var gradient = ctx.createLinearGradient(0, pMinY, 0, pMaxY)
							gradient.addColorStop(pZeroYRatio-0.0001, "" + appletConfig.meteogramPositiveTempColor)
							gradient.addColorStop(pZeroYRatio, "" + appletConfig.meteogramNegativeTempColor)
							ctx.strokeStyle = gradient
						}
						drawCurve(ctx, path)


						// yAxis label: precipitation
						var lastLabelText = ''
						var lastLabelVisible = false
						var lastLabelStaggered = false
						for (var i = 1; i < graph.gridData.length; i++) {
							var item = graph.gridData[i]
							// console.log('label', graph.rainUnits, i, item.precipitation)
								if (item.precipitation && (
									(graph.rainUnits === 'mm' && item.precipitation > 0.3)
									|| (graph.rainUnits === 'in' && item.precipitation > 0.01)
									|| (graph.rainUnits === '%')
								)) {
								var labelText = formatPrecipitation(item.precipitation)

							if (labelText == lastLabelText) {
								lastLabelText = labelText
								lastLabelVisible = false
								lastLabelStaggered = false
								continue
								}

								ctx.fillStyle = "" + appletConfig.meteogramPrecipitationTextColor
								ctx.font = "12px sans-serif"
								ctx.strokeStyle = "" + appletConfig.meteogramPrecipitationTextOutlineColor
								ctx.lineWidth = 3

								var labelWidth = ctx.measureText(labelText).width
								var p
								// If there isn't enough room
								if (gridDataAreaWidth < labelWidth) { // left align using previous point
									p = graph.gridPoint(i-1, graph.yAxisMin)
									ctx.textAlign = 'left'
								} else { // otherwise right align
									p = graph.gridPoint(i, graph.yAxisMin)
									ctx.textAlign = 'end'
								}

								var pY = graph.gridY + 6

							// Stagger the labels so they don't overlap.
							if (gridDataAreaWidth < labelWidth && lastLabelVisible && !lastLabelStaggered) {
								pY += 12 // 12px
								lastLabelStaggered = true
							} else {
								lastLabelStaggered = false
								}
								lastLabelVisible = true
								lastLabelText = labelText

								ctx.strokeText(labelText, p.x, pY)
								ctx.fillText(labelText, p.x, pY)
							} else {
								lastLabelText = ''
								lastLabelVisible = false
								lastLabelStaggered = false
						}
					}
					// if (graph.showYAxisRainMax) {
					// 	context.fillStyle = graph.precipitationColor
					// 	context.font = "12px sans-serif"
					// 	context.textAlign = 'end'
					// 	var labelText = graph.yAxisRainMax + 'mm';
					// 	context.strokeStyle = graph.precipitationTextOulineColor;
					// 	context.lineWidth = 3;
					// 	context.strokeText(labelText, graph.gridX2, graph.gridY + 6)
					// 	context.fillText(labelText, graph.gridX2, graph.gridY + 6)
					// }
					

					// Area
					graph.updateGridItemAreas()

					// console.log('painted')
				}

			}


 
			Repeater {
				id: gridDataAreas
				anchors.fill: parent
				model: ListModel {}

				delegate: Rectangle {
					x: modelData.areaX+modelData.areaWidth
					y: modelData.areaY-modelData.areaHeight
					width: modelData.areaWidth
					height: modelData.areaHeight
					// color: ["#880", "#008"][index % 2]
					color: "transparent"

					PlasmaCore.ToolTipArea {
						id: tooltip
						anchors.fill: parent
						icon: modelData.gridItem.weatherIcon
						mainText: modelData.gridItem.tooltipMainText
						subText: modelData.gridItem.tooltipSubText
						location: PlasmaCore.Types.BottomEdge
					}

						FontIcon {
							id: weatherIcon
							visible: modelData.showIcon
							anchors.centerIn: parent
							color: appletConfig.meteogramIconColor
							source: modelData.aggregratedIcon
							width: appletConfig.meteogramIconSize
							height: appletConfig.meteogramIconSize
							opacity: tooltip.containsMouse ? 0.1 : 1
							showOutline: meteogramView.showIconOutline
						}

					Component.onCompleted: {
						// console.log(x, y)
					}
				}

			}


		}
	}

	Component.onCompleted: {
		graph.update()
	}

	function parseWeatherForecast(currentWeatherData, data) {
		lastCurrentWeatherData = currentWeatherData || null
		lastHourlyWeatherData = data || { list: [] }

		if (plasmoid.configuration.debugging) {
			var hourlyCount = (data && data.list && data.list.length) ? data.list.length : 0
			var hasCurrent = !!currentWeatherData
			console.log("[eventcalendar:debug] MeteogramView.parseWeatherForecast",
				"current=", hasCurrent,
				"hourlyCount=", hourlyCount,
				"view=", Math.round(meteogramView.width) + "x" + Math.round(meteogramView.height))
		}

		var list = (data && data.list && data.list.length) ? data.list : []
		var gData = []
		var hoursPerDataPoint = Math.max(1, meteogramView.dataPointHours || 1)
		var hourStepMs = hoursPerDataPoint * 60 * 60 * 1000
		var nowMs = Date.now()

		function parseHourlyWeatherItem(item, fallbackTimestampMs) {
			if (!item || typeof item !== "object") {
				return null
			}

			var temp = Number(item.temp)
			if (!isFinite(temp)) {
				return null
			}

			var dtMs = Number(item.dt) * 1000
			if (!isFinite(dtMs) || dtMs <= 0) {
				dtMs = (typeof fallbackTimestampMs === "number" && isFinite(fallbackTimestampMs))
					? fallbackTimestampMs
					: Date.now()
			}
			var dt = new Date(dtMs)
			if (isNaN(dt.getTime())) {
				dt = new Date()
				dtMs = dt.getTime()
			}

			var tooltipSubText = item.description ? ("" + item.description) : ""
			var precipitation = Number(item.precipitation)
			if (isFinite(precipitation) && precipitation > 0) {
				tooltipSubText += " (" + formatPrecipitation(precipitation) + ")"
			}
			if (tooltipSubText.length > 0) {
				tooltipSubText += "<br>"
			}
			tooltipSubText += temp + "°"

			var tooltipMainText = Qt.formatDate(dt, Qt.locale().dateFormat(Locale.LongFormat))
				+ " "
				+ Qt.formatTime(dt, appletConfig.timeFormatShort)

			return {
				y: temp,
				xTimestamp: dtMs,
				precipitation: isFinite(precipitation) ? precipitation : 0,
				tooltipMainText: tooltipMainText,
				tooltipSubText: tooltipSubText,
				weatherIcon: item.iconName || "question"
			}
		}

		function normalizeData(points) {
			if (!points || points.length === 0) {
				return []
			}

			var sorted = points.concat().sort(function(a, b) {
				return a.xTimestamp - b.xTimestamp
			})

			var byBucket = {}
			for (var i = 0; i < sorted.length; i++) {
				var p = sorted[i]
				var bucketKey = "" + Math.floor(p.xTimestamp / hourStepMs)
				var existing = byBucket[bucketKey]
				if (!existing) {
					byBucket[bucketKey] = p
					continue
				}
				var existingDist = Math.abs(existing.xTimestamp - nowMs)
				var candidateDist = Math.abs(p.xTimestamp - nowMs)
				if (candidateDist <= existingDist) {
					byBucket[bucketKey] = p
				}
			}

			var keys = Object.keys(byBucket).sort(function(a, b) {
				return Number(a) - Number(b)
			})
			var deduped = []
			for (var j = 0; j < keys.length; j++) {
				deduped.push(byBucket[keys[j]])
			}
			return deduped
		}

		function bucketizeForDisplay(points, bucketHours, windowStartMs, visibleHours) {
			if (!points || points.length === 0) {
				return []
			}

			var safeBucketHours = Math.max(1, Math.round(bucketHours || 1))
			var bucketMs = safeBucketHours * 60 * 60 * 1000
			var windowHours = Math.max(3, Number(visibleHours) || safeBucketHours)
			var bucketCount = Math.max(1, Math.ceil(windowHours / safeBucketHours))
			var out = []

			function nearestPoint(ts) {
				var closest = points[0]
				var minDist = Math.abs(points[0].xTimestamp - ts)
				for (var idx = 1; idx < points.length; idx++) {
					var dist = Math.abs(points[idx].xTimestamp - ts)
					if (dist < minDist) {
						closest = points[idx]
						minDist = dist
					}
				}
				return closest
			}

			for (var bucketIndex = 0; bucketIndex <= bucketCount; bucketIndex++) {
				var bucketStart = windowStartMs + (bucketIndex * bucketMs)
				var bucketEnd = bucketStart + bucketMs
				var bucket = []
				for (var i = 0; i < points.length; i++) {
					var point = points[i]
					if (point.xTimestamp >= bucketStart && point.xTimestamp < bucketEnd) {
						bucket.push(point)
					}
				}
				if (bucket.length === 0) {
					bucket.push(nearestPoint(bucketStart))
				}

				var representative = bucket[Math.floor(bucket.length / 2)]
				var icons = []
				var precipitation = 0
				for (var j = 0; j < bucket.length; j++) {
					var p = bucket[j]
					icons.push(p.weatherIcon || "question")
					precipitation += Number(p.precipitation) || 0
				}

				out.push({
					y: representative.y,
					xTimestamp: bucketStart,
					precipitation: precipitation,
					tooltipMainText: representative.tooltipMainText,
					tooltipSubText: representative.tooltipSubText,
					weatherIcon: WeatherApi.getMostSevereIcon(icons)
				})
			}

			return out
		}

		function withMockPrecipitation(points) {
			if (!plasmoid.configuration.weatherMockPrecipitation) {
				return points
			}
			var out = []
			for (var i = 0; i < points.length; i++) {
				var p = points[i]
				var syntheticMm = ((Math.sin((i + 1) * 1.15) + 1) * 1.4)
					+ ((i % 4 === 0) ? 2.2 : 0)
					+ ((i % 7 === 0) ? 0.9 : 0)
				syntheticMm = Math.round(syntheticMm * 10) / 10
				var syntheticPrecip = syntheticMm
				if (graph.rainUnits === "in") {
					syntheticPrecip = syntheticMm / 25.4
				}
				out.push({
					y: p.y,
					xTimestamp: p.xTimestamp,
					precipitation: syntheticPrecip,
					tooltipMainText: p.tooltipMainText,
					tooltipSubText: p.tooltipSubText,
					weatherIcon: p.weatherIcon
				})
			}
			return out
		}

		if (currentWeatherData) {
			var currentPoint = parseHourlyWeatherItem(currentWeatherData, nowMs)
			if (currentPoint) {
				gData.push(currentPoint)
			}
		} else if (list.length > 0) {
			gData.push({
				y: Number(list[0].temp) || 0,
				xTimestamp: nowMs,
				precipitation: 0
			})
		}

		for (var itemIndex = 0; itemIndex < list.length; itemIndex++) {
			var item = list[itemIndex]
			var fallbackTimestampMs = gData.length > 0
				? gData[gData.length - 1].xTimestamp + hourStepMs
				: nowMs
			var parsedItem = parseHourlyWeatherItem(item, fallbackTimestampMs)
			if (parsedItem) {
				gData.push(parsedItem)
			}
		}

		gData = normalizeData(gData)
		if (gData.length === 0) {
			graph.gridData = []
			graph.update()
			meteogramView.populated = false
			return
		}

		// Use deterministic hour windows to keep "show next X hours" stable.
		var windowStartMs = nowMs - (nowMs % hourStepMs)
		var visibleHours = Math.max(3, Number(meteogramView.visibleDuration) || 24)
		var windowEndMs = windowStartMs + visibleHours * 60 * 60 * 1000
		var windowPoints = []
		for (var w = 0; w < gData.length; w++) {
			var point = gData[w]
			if (point.xTimestamp >= windowStartMs - hourStepMs
				&& point.xTimestamp <= windowEndMs + hourStepMs
			) {
				windowPoints.push(point)
			}
		}
		if (windowPoints.length > 0) {
			gData = windowPoints
		}

		gData = bucketizeForDisplay(gData, meteogramView.displayBucketHours, windowStartMs, visibleHours)
		gData = withMockPrecipitation(gData)

		if (gData.length < 2) {
			graph.gridData = gData
			graph.update()
			meteogramView.populated = gData.length > 0
			return
		}

		gData = formatXAxisLabels(gData)
		graph.gridData = gData
		graph.update()
		meteogramView.populated = true
	}

	function formatXAxisLabels(gData) {
		for (var i = 0; i < gData.length; i++) {
			var isEdge = (i === 0) || (i === gData.length - 1)
			var showLabel = !isEdge && (i % Math.ceil(meteogramView.xAxisLabelEvery) == 0)
			if (showLabel) {
				var date = new Date(gData[i].xTimestamp)
				var hour = date.getHours()
				var label = ''
				if (clock24h) {
					label += hour
				} else {
					// 12 hour clock
					// (3am = 3) (11pm = 11p)
					label += hour % 12 === 0 ? 12 : hour % 12
					label += (hour < 12 ? '' : 'p')
				}
				gData[i].xLabel = label
			} else {
				gData[i].xLabel = ''
			}
		}
		return gData
	}

	function formatDecimal(x, afterDecimal) {
		return x >= 1 ? Math.round(x) : x.toFixed(afterDecimal)
	}
	function formatPrecipitation(value) {
		var valueText = formatDecimal(value, 1)
		if (graph.rainUnits === 'mm') {
			return i18n("%1mm", valueText)
		} else if (graph.rainUnits === 'in') {
			return i18n("%1in", valueText)
		} else { // rainUnits == '%'
			return i18n('%1%', valueText) // Not translated as we use ''
		}
	}
}
