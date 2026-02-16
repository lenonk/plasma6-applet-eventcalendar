.pragma library

.import "../lib/Requests.js" as Requests

function weatherIsSetup(config) {
	// Config values can arrive as strings depending on the config backend; normalize.
	var lat = Number(config.openMeteoLatitude)
	var lon = Number(config.openMeteoLongitude)
	if (!isFinite(lat) || !isFinite(lon)) {
		return false
	}
	// Default values are 0/0; consider "configured" if the user picked a location name
	// or changed the coordinates away from the default.
	return !!config.openMeteoLocationName || lat !== 0 || lon !== 0
}

function openLocationUrl(latitude, longitude) {
	if (typeof latitude !== "number" || typeof longitude !== "number") {
		return
	}
	if (!isFinite(latitude) || !isFinite(longitude)) {
		return
	}
	var lat = latitude.toFixed(5)
	var lon = longitude.toFixed(5)
	var url = "https://www.openstreetmap.org/?mlat=" + encodeURIComponent(lat)
		+ "&mlon=" + encodeURIComponent(lon)
		+ "#map=10/" + encodeURIComponent(lat) + "/" + encodeURIComponent(lon)
	Qt.openUrlExternally(url)
}

function openForecastUrl(latitude, longitude) {
	if (typeof latitude !== "number" || typeof longitude !== "number") {
		return
	}
	if (!isFinite(latitude) || !isFinite(longitude)) {
		return
	}
	var lat = latitude.toFixed(4)
	var lon = longitude.toFixed(4)
	// Open-Meteo is an API. Use a public forecast page that accepts raw coordinates.
	Qt.openUrlExternally("https://www.timeanddate.com/weather/@" + encodeURIComponent(lat) + "," + encodeURIComponent(lon) + "/ext")
}

function openCityUrl(config) {
	openForecastUrl(Number(config.openMeteoLatitude), Number(config.openMeteoLongitude))
}

function parseIsoLocal(s) {
	if (!s) return null
	var m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2}))?)?/.exec(s)
	if (!m) {
		var d = new Date(s)
		return isNaN(d) ? null : d
	}
	var year = parseInt(m[1], 10)
	var month = parseInt(m[2], 10) - 1
	var day = parseInt(m[3], 10)
	var hour = m[4] ? parseInt(m[4], 10) : 0
	var minute = m[5] ? parseInt(m[5], 10) : 0
	var second = m[6] ? parseInt(m[6], 10) : 0
	return new Date(year, month, day, hour, minute, second)
}

function toKelvin(celsius) {
	return celsius + 273.15
}

function mapTemp(config, temp) {
	if (typeof temp !== "number") return temp
	if (config.weatherUnits === "kelvin") {
		// Open-Meteo doesn't provide Kelvin. Fetch in Celsius and convert.
		return toKelvin(temp)
	}
	return temp
}

var weatherCodeMap = {
	0:  { iconName: "weather-clear",              text: "Clear",         description: "Clear sky" },
	1:  { iconName: "weather-clear",              text: "Mostly Clear",  description: "Mainly clear" },
	2:  { iconName: "weather-few-clouds",         text: "Partly Cloudy", description: "Partly cloudy" },
	3:  { iconName: "weather-overcast",           text: "Overcast",      description: "Overcast" },
	45: { iconName: "weather-fog",                text: "Fog",           description: "Fog" },
	48: { iconName: "weather-fog",                text: "Fog",           description: "Depositing rime fog" },
	51: { iconName: "weather-showers-scattered",  text: "Drizzle",       description: "Light drizzle" },
	53: { iconName: "weather-showers-scattered",  text: "Drizzle",       description: "Moderate drizzle" },
	55: { iconName: "weather-showers",            text: "Drizzle",       description: "Dense drizzle" },
	56: { iconName: "weather-freezing-rain",      text: "Freezing Drizzle", description: "Light freezing drizzle" },
	57: { iconName: "weather-freezing-rain",      text: "Freezing Drizzle", description: "Dense freezing drizzle" },
	61: { iconName: "weather-showers",            text: "Rain",          description: "Slight rain" },
	63: { iconName: "weather-showers",            text: "Rain",          description: "Moderate rain" },
	65: { iconName: "weather-showers",            text: "Rain",          description: "Heavy rain" },
	66: { iconName: "weather-freezing-rain",      text: "Freezing Rain", description: "Light freezing rain" },
	67: { iconName: "weather-freezing-rain",      text: "Freezing Rain", description: "Heavy freezing rain" },
	71: { iconName: "weather-snow",               text: "Snow",          description: "Slight snow fall" },
	73: { iconName: "weather-snow",               text: "Snow",          description: "Moderate snow fall" },
	75: { iconName: "weather-snow",               text: "Snow",          description: "Heavy snow fall" },
	77: { iconName: "weather-snow",               text: "Snow",          description: "Snow grains" },
	80: { iconName: "weather-showers-scattered",  text: "Showers",       description: "Slight rain showers" },
	81: { iconName: "weather-showers",            text: "Showers",       description: "Moderate rain showers" },
	82: { iconName: "weather-showers",            text: "Showers",       description: "Violent rain showers" },
	85: { iconName: "weather-snow-scattered-day", text: "Snow Showers",  description: "Slight snow showers" },
	86: { iconName: "weather-snow",               text: "Snow Showers",  description: "Heavy snow showers" },
	95: { iconName: "weather-storm",              text: "Thunderstorm",  description: "Thunderstorm" },
	96: { iconName: "weather-storm",              text: "Thunderstorm",  description: "Thunderstorm with slight hail" },
	99: { iconName: "weather-storm",              text: "Thunderstorm",  description: "Thunderstorm with heavy hail" },
}

function codeToInfo(code) {
	var info = weatherCodeMap[code]
	if (!info) {
		return { iconName: "weather-severe-alert", text: "", description: "" }
	}
	return info
}

function handleError(funcName, callback, err, data, xhr) {
	console.error("[eventcalendar]", funcName + ".err", err, xhr && xhr.status, data)
	return callback(err, data, xhr)
}

	function buildForecastUrl(args) {
		var base = "https://api.open-meteo.com/v1/forecast"
		var url = base
			+ "?latitude=" + encodeURIComponent(args.latitude)
			+ "&longitude=" + encodeURIComponent(args.longitude)
			+ "&timezone=auto"
			+ "&current=temperature_2m,weather_code"
			+ "&hourly=temperature_2m,precipitation,weather_code"
			+ "&daily=temperature_2m_min,temperature_2m_max,weather_code"
		// 10+ days is useful for the agenda's multi-day view. Open-Meteo supports up to 16.
		+ "&forecast_days=16"
		+ "&past_days=0"
		+ "&temperature_unit=" + encodeURIComponent(args.temperatureUnit || "celsius")
		+ "&precipitation_unit=mm"
		+ "&timeformat=iso8601"
	return url
}

function fetchForecast(args, callback) {
	if (typeof args.latitude !== "number" || typeof args.longitude !== "number") {
		return callback("Open-Meteo latitude/longitude not set")
	}
	var url = buildForecastUrl(args)
	Requests.getJSON(url, callback)
}

function updateDailyWeather(config, callback) {
	var temperatureUnit = (config.weatherUnits === "imperial") ? "fahrenheit" : "celsius"
	fetchForecast({
		latitude: Number(config.openMeteoLatitude),
		longitude: Number(config.openMeteoLongitude),
		temperatureUnit: temperatureUnit,
	}, function(err, data, xhr) {
		if (err) return handleError("OpenMeteo.fetchForecast(daily)", callback, err, data, xhr)

		var daily = data && data.daily ? data.daily : {}
		var times = daily.time || []
		var mins = daily.temperature_2m_min || []
		var maxs = daily.temperature_2m_max || []
		var codes = daily.weather_code || []

		var out = { list: [] }
		for (var i = 0; i < times.length; i++) {
			var d = parseIsoLocal(times[i])
			if (!d) continue
			var dt = Math.floor(d.getTime() / 1000)
			var minT = mapTemp(config, mins[i])
			var maxT = mapTemp(config, maxs[i])
			var info = codeToInfo(codes[i])
			out.list.push({
				dt: dt,
				temp: { min: minT, max: maxT },
				iconName: info.iconName,
				text: info.text,
				description: info.description,
				notes: "",
			})
		}

		callback(null, out, xhr)
	})
}

	function updateHourlyWeather(config, callback) {
		var temperatureUnit = (config.weatherUnits === "imperial") ? "fahrenheit" : "celsius"
		fetchForecast({
			latitude: Number(config.openMeteoLatitude),
			longitude: Number(config.openMeteoLongitude),
			temperatureUnit: temperatureUnit,
		}, function(err, data, xhr) {
			if (err) return handleError("OpenMeteo.fetchForecast(hourly)", callback, err, data, xhr)

			var now = Date.now()
			var hourly = data && data.hourly ? data.hourly : {}
			var times = hourly.time || []
			var temps = hourly.temperature_2m || []
			var precs = hourly.precipitation || []
			var codes = hourly.weather_code || []

			var list = []
			for (var i = 0; i < times.length; i++) {
				var d = parseIsoLocal(times[i])
				if (!d) continue
				var dtMs = d.getTime()

				// Keep near-current + future samples; discard old hourly entries.
				if (dtMs < now - (60 * 60 * 1000)) {
					continue
				}

				var info = codeToInfo(codes[i])
				var precipitation = typeof precs[i] === "number" ? precs[i] : 0
				if (config.weatherUnits === "imperial") {
					// Open-Meteo precipitation is in mm; convert to inches for imperial mode.
					precipitation = precipitation / 25.4
				}
				list.push({
					dt: Math.floor(dtMs / 1000),
					temp: mapTemp(config, temps[i]),
					iconName: info.iconName,
					description: info.description,
					precipitation: precipitation,
				})
			}

			var currentPoint = null
			var current = data && data.current ? data.current : null
			if (current && typeof current.temperature_2m === "number") {
				var currentDate = parseIsoLocal(current.time) || new Date()
				var currentInfo = codeToInfo(current.weather_code)
				currentPoint = {
					dt: Math.floor(currentDate.getTime() / 1000),
					temp: mapTemp(config, current.temperature_2m),
					iconName: currentInfo.iconName,
					description: currentInfo.description,
					precipitation: 0,
				}
			}

			callback(null, { list: list, current: currentPoint }, xhr)
		})
	}
