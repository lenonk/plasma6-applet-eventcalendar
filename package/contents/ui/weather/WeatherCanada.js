.pragma library

.import "../lib/Requests.js" as Requests

/* The weather.gc.ca city pages were retired in 2025. The MSC GeoMet API serves the same
citypage forecast as JSON, keyed by the same city ids (eg: on-143).

https://api.weather.gc.ca/collections/citypageweather-realtime
https://eccc-msc.github.io/open-data/msc-data/citypage-weather/readme_citypageweather_en/
*/

function weatherIsSetup(config) {
	if (!!config.weatherCanadaCityId) {
		var matches = /[a-z]{2}-\d+/.exec(config.weatherCanadaCityId)
		return !!matches
	} else {
		return false
	}
}

// https://dd.weather.gc.ca/today/citypage_weather/docs/current_conditions_icon_code_descriptions_e.csv
// https://dd.weather.gc.ca/today/citypage_weather/docs/forecast_conditions_icon_code_descriptions_e.csv
var weatherIconMap = {
	'00': 'weather-clear', // Sunny
	'01': 'weather-clear', // Mainly sunny
	'02': 'weather-few-clouds', // Partly Cloudy
		// A mix of sun and cloud
	'03': 'weather-clouds', // Mainly cloudy
	'04': 'weather-few-clouds', // Increasing cloudiness
	'05': 'weather-few-clouds', // Clearing
	'06': 'weather-showers-scattered', // Chance of showers
	'07': 'weather-snow-rain',
		// Chance of flurries or rain showers [Sun]
		// Rain showers or flurries [Sun]
	'08': 'weather-snow-scattered-day', // Chance of flurries [Sun]
	'09': 'weather-storm', // Chance of thunderstorms. Risk of severe thunderstorms
		// Chance of thunderstorms
	'10': 'weather-clouds', // Cloudy
		// Overcast
	'11': 'weather-showers',
		// Squalls
		// Light Precipitation
		// Heavy Precipitation
	'12': 'weather-showers', // Showers
	'13': 'weather-showers', // Rain
	'14': 'weather-freezing-rain', // Freezing Rain
	'15': 'weather-snow-rain', // Chance of flurries or rain showers [Cloud]
	'16': 'weather-snow',
		// Chance of flurries [Cloud]
		// Flurries [Cloud]
	'17': 'weather-snow', // Snow [Cloud]
	'18': 'weather-snow', // Blizzard
	'19': 'weather-storm', // Chance of showers. Risk of thundershowers
	'20': 'question', // [? Same icon as 24 (fog)]
	'21': 'question', // [? Same icon as 24 (fog)]
	'22': 'weather-few-clouds', // A mix of sun and cloud
	'23': 'weather-fog', // Haze
	'24': 'weather-fog',
		// Fog
		// Fog Patches
		// Ice fog
	'25': 'weather-snow', // Drifting Snow
	'26': 'weather-snow', // Ice Crystals
	'27': 'weather-hail', // Hail
	'28': 'weather-freezing-rain',
		// Drizzle
		// Freezing drizzle

	'29': 'question', // Not available

	'30': 'weather-clear-night', // Clear
	'31': 'weather-few-clouds-night', // A few clouds
	'32': 'weather-few-clouds-night', // Partly cloudy
	'33': 'weather-clouds-night', // Mainly cloudy
	'34': 'weather-few-clouds-night', // Increasing cloudiness
	'35': 'weather-few-clouds-night', // Clearing [Moon]
	'36': 'weather-showers-scattered-night', // Chance of showers
	'37': 'weather-snow-rain-night', // Chance of flurries or rain showers [Moon]
	'38': 'weather-snow', // Chance of flurries [Moon]
	'39': 'weather-storm-night', // Chance of showers. Risk of thunderstorms

	'40': 'weather-snow', // Blowing Snow
	'41': 'wi-tornado', // Funnel Cloud
	'42': 'wi-tornado', // Tornado
	'43': 'wi-windy', // Windy
	'44': 'wi-smoke', // Smoke
	'45': 'wi-sandstorm', // Sandstorm
	'46': 'weather-storm', // Thunderstorm with Hail
	'47': 'weather-storm', // Thunderstorm with Dust Storm
	'48': 'wi-tornado', // Waterspout
}


var weatherIconToTextMap = {}
/* Don't burden translators with these for now.
var weatherIconToTextMap = {
	'weather-clear': i18n("Clear"),
	'weather-clear-night': i18n("Clear"),
	'weather-clouds': i18n("Cloudy"),
	'weather-clouds-night': i18n("Cloudy"),
	'weather-few-clouds': i18n("Cloudy"),
	'weather-few-clouds-night': i18n("Cloudy"),
	'weather-fog': i18n("Fog"),
	'weather-freezing-rain': i18n("Freezing Rain"),
	'weather-hail': i18n("Hail"),
	'weather-overcast': i18n("Overcast"),
	'weather-showers': i18n("Rain"),
	'weather-showers-night': i18n("Rain"),
	'weather-showers-scattered': i18n("Showers"),
	'weather-showers-scattered-night': i18n("Showers"),
	'weather-snow': i18n("Snow"),
	'weather-snow-rain': i18n("Snow/Rain"),
	'weather-snow-rain-night': i18n("Snow/Rain"),
	'weather-snow-scattered-day': i18n("Snow"),
	'weather-snow-scattered-night': i18n("Snow"),
	'weather-storm': i18n("Storm"),
	'weather-storm-night': i18n("Storm"),
	'wi-dust': i18n("Dust"),
	'wi-sandstorm': i18n("Sandstorm"),
	'wi-smoke': i18n("Smoke"),
	'wi-tornado': i18n("Tornado"),
	'wi-windy': i18n("Windy"),
}
*/


var apiUrl = 'https://api.weather.gc.ca/collections/citypageweather-realtime'
var fallbackCityUrl = 'https://weather.gc.ca/canada_e.html'
var cityUrls = {} // cityId -> weather.gc.ca page, filled by fetches

// Bilingual fields look like { en: ..., fr: ... }.
function en(obj) {
	if (obj && typeof obj === 'object' && 'en' in obj) {
		return obj.en
	}
	return obj
}

function toNumber(value) {
	var n = Number(en(value))
	return (value === null || value === undefined || !isFinite(n)) ? NaN : n
}

function iconId(icon) {
	var n = toNumber(icon && icon.value)
	if (isNaN(n)) {
		return ''
	}
	return (n < 10 ? '0' : '') + n
}

function iconName(icon) {
	var id = iconId(icon)
	var name = weatherIconMap[id]
	if (!name && id) {
		console.log('[eventcalendar] WeatherCanada icon not mapped (' + id + ')')
	}
	return name || 'question'
}

// The API is metric only.
function mapTemp(config, celsius) {
	if (isNaN(celsius)) {
		return celsius
	} else if (config.weatherUnits === 'imperial') {
		return Math.round((celsius * 9 / 5 + 32) * 10) / 10
	} else if (config.weatherUnits === 'kelvin') {
		return Math.round((celsius + 273.15) * 100) / 100
	} else {
		return celsius
	}
}

function parsePrecipitation(lop) {
	var value = toNumber(lop && lop.value)
	if (!isNaN(value)) {
		return value
	}
	// Fall back to the minimum of the category's range.
	var category = en(lop && lop.category)
	if (category == 'Low') {
		return 20
	} else if (category == 'Medium') {
		return 60
	} else if (category == 'High') {
		return 70
	} else {
		return 0
	}
}

var weekdays = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday']

function isNightPeriod(period) {
	var name = ('' + (en(period && period.textForecastName) || '')).toLowerCase()
	return name == 'tonight' || /\bnight$/.test(name)
}

// Local midnight of the first forecast period.
function firstPeriodDate(forecastGroup, firstPeriod) {
	var issued = new Date(en(forecastGroup.timestamp))
	if (isNaN(issued)) {
		issued = new Date()
	}
	var date = new Date(issued.getFullYear(), issued.getMonth(), issued.getDate())
	// period.value is "Tuesday" / "Tuesday night"; trust it when the issue date is off by a day.
	var weekday = weekdays.indexOf(('' + (en(firstPeriod && firstPeriod.value) || '')).toLowerCase().split(' ')[0])
	if (weekday >= 0 && weekday != date.getDay()) {
		var diff = (weekday - date.getDay() + 7) % 7
		date.setDate(date.getDate() + (diff == 6 ? -1 : diff == 1 ? 1 : 0))
	}
	return date
}

function periodTemps(forecast) {
	var temps = forecast.temperatures && forecast.temperatures.temperature
	if (!temps) {
		return []
	}
	return Array.isArray(temps) ? temps : [temps]
}

function parseDaily(config, feature) {
	var props = feature && feature.properties
	var forecastGroup = props && props.forecastGroup
	var forecasts = forecastGroup && forecastGroup.forecasts
	if (!forecasts || !forecasts.length) {
		throw new Error('No forecast in response')
	}
	var currentTemp = toNumber(props.currentConditions && props.currentConditions.temperature && props.currentConditions.temperature.value)
	var today = firstPeriodDate(forecastGroup, forecasts[0].period)

	var days = []
	for (var i = 0; i < forecasts.length; i++) {
		var forecast = forecasts[i]
		var night = isNightPeriod(forecast.period)
		if (!night || days.length == 0) {
			var date = new Date(today)
			date.setDate(date.getDate() + days.length)
			days.push({ date: date, high: NaN, low: NaN, icon: null, text: '', notes: [] })
		}
		var day = days[days.length - 1]
		var temps = periodTemps(forecast)
		for (var j = 0; j < temps.length; j++) {
			var value = toNumber(temps[j].value)
			if (en(temps[j]['class']) == 'low') {
				day.low = value
			} else {
				day.high = value
			}
		}
		var abbr = forecast.abbreviatedForecast || {}
		if (!day.icon) { // Prefer the daytime icon, like the old city page.
			day.icon = abbr.icon
			day.text = en(abbr.textSummary) || ''
		}
		var summary = en(forecast.textSummary)
		if (summary) {
			day.notes.push(en(forecast.period.textForecastName) + ': ' + summary)
		}
	}

	var list = []
	for (var k = 0; k < days.length; k++) {
		var d = days[k]
		var high = d.high
		if (isNaN(high) && k == 0) {
			high = isNaN(currentTemp) ? d.low : currentTemp // Evening: no daytime high left.
		}
		if (isNaN(high) && isNaN(d.low)) {
			continue
		}
		list.push({
			dt: Math.floor(d.date.valueOf() / 1000),
			temp: {
				max: mapTemp(config, high),
				min: mapTemp(config, d.low), // NaN shows "?" on the last day.
			},
			iconName: iconName(d.icon),
			text: d.text,
			description: d.text,
			notes: d.notes.join('\n'),
		})
	}
	return { list: list }
}

function parseHourly(config, feature) {
	var props = feature && feature.properties
	var group = props && props.hourlyForecastGroup
	var hourly = (group && group.hourlyForecasts) || []
	var list = []
	for (var i = 0; i < hourly.length; i++) {
		var item = hourly[i]
		var dtMs = Date.parse(en(item.timestamp))
		var temp = toNumber(item.temperature && item.temperature.value)
		if (isNaN(dtMs) || isNaN(temp)) {
			continue
		}
		list.push({
			dt: Math.floor(dtMs / 1000),
			temp: mapTemp(config, temp),
			iconName: iconName(item.iconCode),
			description: en(item.condition) || '',
			precipitation: parsePrecipitation(item.lop),
		})
	}
	if (!list.length) {
		throw new Error('No hourly forecast in response')
	}

	var current = null
	var cc = props.currentConditions
	var currentTemp = toNumber(cc && cc.temperature && cc.temperature.value)
	if (!isNaN(currentTemp)) {
		var currentMs = Date.parse(en(cc.timestamp))
		current = {
			dt: Math.floor((isNaN(currentMs) ? Date.now() : currentMs) / 1000),
			temp: mapTemp(config, currentTemp),
			iconName: iconName(cc.iconCode),
			description: en(cc.condition) || '',
			precipitation: 0,
		}
	}
	return { list: list, current: current }
}

function getCityApiUrl(cityId) {
	return apiUrl + '/items/' + encodeURIComponent(cityId) + '?f=json&lang=en'
}

function getCityListUrl() {
	return apiUrl + '/items?f=json&lang=en&skipGeometry=true&limit=2000&properties=identifier,name.en,url.en'
}

function getCityUrl(cityId) {
	return cityUrls[cityId] || fallbackCityUrl
}

function openCityUrl(config) {
	var cityId = config.weatherCanadaCityId
	if (cityUrls[cityId]) {
		return Qt.openUrlExternally(cityUrls[cityId])
	}
	fetchCity(cityId, function(err) {
		Qt.openUrlExternally(getCityUrl(cityId))
	})
}

function handleError(funcName, callback, err, data, xhr) {
	console.error('[eventcalendar]', funcName + '.err', err, xhr && xhr.status, data)
	return callback(err, data, xhr)
}

// Daily and hourly read the same document; share one response for a few minutes.
var cacheMs = 5 * 60 * 1000
var cache = {} // cityId -> { at, err, data, xhr, waiting: [callback] }

function fetchCity(cityId, callback) {
	var entry = cache[cityId]
	if (entry && entry.waiting) {
		entry.waiting.push(callback)
		return
	}
	if (entry && !entry.err && Date.now() - entry.at < cacheMs) {
		return callback(null, entry.data, entry.xhr)
	}
	entry = { at: 0, waiting: [callback] }
	cache = {}
	cache[cityId] = entry
	Requests.getJSON(getCityApiUrl(cityId), function(err, data, xhr) {
		if (!err && !(data && data.properties)) {
			err = 'Invalid response'
		}
		if (!err) {
			var pageUrl = en(data.properties.url)
			if (pageUrl) {
				cityUrls[cityId] = pageUrl
			}
		}
		var waiting = entry.waiting
		entry.at = Date.now()
		entry.err = err
		entry.data = data
		entry.xhr = xhr
		entry.waiting = null
		for (var i = 0; i < waiting.length; i++) {
			waiting[i](err, data, xhr)
		}
	})
}

function updateDailyWeather(config, callback) {
	fetchCity(config.weatherCanadaCityId, function(err, data, xhr) {
		if (err) return handleError('WeatherCanada.fetchDailyWeatherForecast', callback, err, '', xhr)
		try {
			var weatherData = parseDaily(config, data)
		} catch (e) {
			return handleError('WeatherCanada.parseDaily', callback, e.message, '', xhr)
		}
		callback(null, weatherData, xhr)
	})
}

function updateHourlyWeather(config, callback) {
	fetchCity(config.weatherCanadaCityId, function(err, data, xhr) {
		if (err) return handleError('WeatherCanada.fetchHourlyWeatherForecast', callback, err, '', xhr)
		try {
			var weatherData = parseHourly(config, data)
		} catch (e) {
			return handleError('WeatherCanada.parseHourly', callback, e.message, '', xhr)
		}
		callback(null, weatherData, xhr)
	})
}

// @returns [{ id: 'on-143', name: 'Toronto', url: 'https://weather.gc.ca/...' }, ...]
function parseCityList(data) {
	var features = (data && data.features) || []
	var cityList = []
	for (var i = 0; i < features.length; i++) {
		var props = features[i].properties || {}
		var id = props.identifier || features[i].id
		if (!id) {
			continue
		}
		cityList.push({
			id: '' + id,
			name: '' + (en(props.name) || id),
			url: '' + (en(props.url) || fallbackCityUrl),
		})
	}
	cityList.sort(function(a, b) {
		return a.name.localeCompare(b.name)
	})
	return cityList
}

function fetchCityList(callback) {
	Requests.getJSON(getCityListUrl(), function(err, data, xhr) {
		if (err) return handleError('WeatherCanada.fetchCityList', callback, err, '', xhr)
		var cityList = parseCityList(data)
		for (var i = 0; i < cityList.length; i++) {
			cityUrls[cityList[i].id] = cityList[i].url
		}
		callback(null, cityList, xhr)
	})
}
