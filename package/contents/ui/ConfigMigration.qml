import QtQuick 2.0
import QtQml

import org.kde.plasma.workspace.calendar as PlasmaCalendar

import "./calendars/PlasmaCalendarUtils.js" as PlasmaCalendarUtils

Item {
	id: root
	visible: false
	width: 0
	height: 0

	signal migrate()

	// Used to migrate legacy display-name based configs (from buggy versions) back to stable plugin ids.
	PlasmaCalendar.EventPluginsManager {
		id: eventPluginsManager
	}
	property var pluginDisplayToIdLower: ({}) // { "holidays": "holidaysevents", ... }
	property var knownPluginIds: ({}) // { "holidaysevents": true, ... }

	Instantiator {
		id: pluginInstantiator
		model: eventPluginsManager.model
		delegate: QtObject {
			Component.onCompleted: {
				var display = ("" + model.display).trim()
				var pluginId = ("" + model.pluginId).trim()
				if (!display || !pluginId) return
				root.pluginDisplayToIdLower[display.toLowerCase()] = pluginId
				root.knownPluginIds[pluginId] = true
			}
		}
	}

	function resolvePluginId(value) {
		if (typeof value === "undefined" || value === null) return ""
		var raw = ("" + value).trim()
		if (!raw) return ""

		// Normalize paths and ".so" filenames into ids (eg: "/.../holidaysevents.so" -> "holidaysevents").
		var norm = PlasmaCalendarUtils.getPluginFilename(raw)
		if (root.knownPluginIds[norm]) {
			return norm
		}

		// Legacy bug: some versions stored plugin display names (eg: "Astronomical Events").
		var byDisplay = root.pluginDisplayToIdLower[norm.toLowerCase()] || root.pluginDisplayToIdLower[raw.toLowerCase()]
		if (byDisplay) {
			return byDisplay
		}

		// Unknown plugin id; keep normalized value as-is.
		return norm
	}

	function normalizeEnabledPluginsList(value) {
		var list = PlasmaCalendarUtils.pluginPathToFilenameList(value)
		var out = []
		for (var i = 0; i < list.length; i++) {
			var id = resolvePluginId(list[i])
			if (!id) continue
			if (out.indexOf(id) === -1) {
				out.push(id)
			}
		}
		return out
	}

	function copy(oldKey, newKey) {
		if (typeof plasmoid.configuration[oldKey] === 'undefined') return
		if (typeof plasmoid.configuration[newKey] === 'undefined') return
		if (plasmoid.configuration[oldKey] === plasmoid.configuration[newKey]) return
		plasmoid.configuration[newKey] = plasmoid.configuration[oldKey]
		console.log('[eventcalendar:migrate] copy ' + oldKey + ' => ' + newKey + ' (value: ' + plasmoid.configuration[oldKey] + ')')
	}

	Timer {
		interval: 0
		running: true
		repeat: false
		onTriggered: root.migrate()
	}
	Connections {
		target: eventPluginsManager
		// If plugin list loads after startup, rerun normalization once it is available.
		function onPluginsChanged() { root.migrate() }
	}
	onMigrate: {
		function normalizeEnabledCalendarPlugins() {
			// Normalize values on every startup: old configs may have ".so" filenames
			// or outdated ids, and Plasma 6 exposes different plugin ids/paths.
			var oldValue = plasmoid.configuration.enabledCalendarPlugins
			var newValue = normalizeEnabledPluginsList(oldValue)
			if (JSON.stringify(oldValue) !== JSON.stringify(newValue)) {
				plasmoid.configuration.enabledCalendarPlugins = newValue
				console.log('[eventcalendar:migrate] normalize enabledCalendarPlugins (' + oldValue + ' => ' + newValue + ')')
			}
		}

		normalizeEnabledCalendarPlugins()

		// Normalize legacy/unsupported weather service values.
		if (plasmoid.configuration.weatherService
			&& plasmoid.configuration.weatherService !== "OpenMeteo"
			&& plasmoid.configuration.weatherService !== "WeatherCanada"
		) {
			var oldService = plasmoid.configuration.weatherService
			plasmoid.configuration.weatherService = "OpenMeteo"
			console.log("[eventcalendar:migrate] weatherService " + oldService + " => OpenMeteo")
		}

		// Modified in: v72
		if (!plasmoid.configuration.v72Migration) {
			var oldValue = plasmoid.configuration.enabledCalendarPlugins
			var newValue = normalizeEnabledPluginsList(plasmoid.configuration.enabledCalendarPlugins)
			plasmoid.configuration.enabledCalendarPlugins = newValue
			console.log('[eventcalendar:migrate] convert enabledCalendarPlugins (' + oldValue + ' => ' + newValue + ')')

			plasmoid.configuration.v72Migration = true
		}

		// Renamed in: v71
		if (!plasmoid.configuration.v71Migration) {
			copy('widget_show_meteogram', 'widgetShowMeteogram')
			copy('widget_show_timer', 'widgetShowTimer')
			copy('widget_show_agenda', 'widgetShowAgenda')
			copy('widget_show_calendar', 'widgetShowCalendar')
			copy('timer_sfx_enabled', 'timerSfxEnabled')
			copy('timer_sfx_filepath', 'timerSfxFilepath')
			copy('timer_repeats', 'timerRepeats')
			copy('clock_fontfamily', 'clockFontFamily')
			copy('clock_timeformat', 'clockTimeFormat1')
			copy('clock_timeformat_2', 'clockTimeFormat2')
			copy('clock_line_2', 'clockShowLine2')
			copy('clock_line_2_height_ratio', 'clockLine2HeightRatio')
			copy('clock_line_1_bold', 'clockLineBold1')
			copy('clock_line_2_bold', 'clockLineBold2')
			copy('clock_maxheight', 'clockMaxHeight')
			copy('clock_mousewheel_up', 'clockMouseWheelUp')
			copy('clock_mousewheel_down', 'clockMouseWheelDown')
			copy('show_outlines', 'showOutlines')

			copy('month_show_border', 'monthShowBorder')
			copy('month_show_weeknumbers', 'monthShowWeekNumbers')
			copy('month_eventbadge_type', 'monthEventBadgeType')
			copy('month_today_style', 'monthTodayStyle')
			copy('month_cell_radius', 'monthCellRadius')

			copy('agenda_newevent_remember_calendar', 'agendaNewEventRememberCalendar')
			copy('agenda_newevent_last_calendar_id', 'agendaNewEventLastCalendarId')
			copy('agenda_weather_show_icon', 'agendaWeatherShowIcon')
			copy('agenda_weather_icon_height', 'agendaWeatherIconHeight')
			copy('agenda_weather_show_text', 'agendaWeatherShowText')
			copy('agenda_breakup_multiday_events', 'agendaBreakupMultiDayEvents')
			copy('agenda_inProgressColor', 'agendaInProgressColor')
			copy('agenda_fontSize', 'agendaFontSize')

			copy('events_pollinterval', 'eventsPollInterval')

			copy('weather_canada_city_id', 'weatherCanadaCityId')
			copy('weather_service', 'weatherService')
			copy('weather_units', 'weatherUnits')
			copy('meteogram_hours', 'meteogramHours')
			copy('meteogram_textColor', 'meteogramTextColor')
			copy('meteogram_gridColor', 'meteogramGridColor')
			copy('meteogram_rainColor', 'meteogramRainColor')
			copy('meteogram_positiveTempColor', 'meteogramPositiveTempColor')
			copy('meteogram_negativeTempColor', 'meteogramNegativeTempColor')
			copy('meteogram_iconColor', 'meteogramIconColor')

			plasmoid.configuration.v71Migration = true
		}
	}

}
