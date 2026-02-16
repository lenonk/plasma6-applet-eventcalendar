import QtQuick
import org.kde.plasma.configuration as PlasmaConfig

PlasmaConfig.ConfigModel {
	PlasmaConfig.ConfigCategory {
		name: i18n("General")
		icon: "clock"
		source: "config/ConfigGeneral.qml"
	}
	// ConfigCategory {
	// 	name: i18n("Clock")
	// 	icon: "clock"
	// 	source: "config/ConfigClock.qml"
	// }
	PlasmaConfig.ConfigCategory {
		name: i18n("Layout")
		icon: "grid-rectangular"
		source: "config/ConfigLayout.qml"
	}
	PlasmaConfig.ConfigCategory {
		name: i18n("Timezones")
		icon: "preferences-system-time"
		source: "config/ConfigTimezones.qml"
	}
	PlasmaConfig.ConfigCategory {
		name: i18n("Calendar")
		icon: "view-calendar"
		source: "config/ConfigCalendar.qml"
	}
	PlasmaConfig.ConfigCategory {
		name: i18n("Agenda")
		icon: "view-calendar-agenda"
		source: "config/ConfigAgenda.qml"
	}
	PlasmaConfig.ConfigCategory {
		name: i18n("Events")
		icon: "view-calendar-week"
		source: "config/ConfigEvents.qml"
	}
	PlasmaConfig.ConfigCategory {
		name: i18n("ICalendar (.ics)")
		icon: "text-calendar"
		source: "config/ConfigICal.qml"
		visible: plasmoid.configuration.debugging
	}
	PlasmaConfig.ConfigCategory {
		name: i18n("Google Calendar")
		icon: Qt.resolvedUrl("../icons/google_calendar_96px.png")
		source: "config/ConfigGoogleCalendar.qml"
	}
	PlasmaConfig.ConfigCategory {
		name: i18n("Weather")
		icon: "weather-clear"
		source: "config/ConfigWeather.qml"
	}
	PlasmaConfig.ConfigCategory {
		name: i18n("Advanced")
		icon: "applications-development"
		source: "lib/ConfigAdvanced.qml"
		visible: plasmoid.configuration.debugging
	}

	// Keep these for config dialog expectations.
	property bool immutable: false
	property bool isDefaults: true
}
