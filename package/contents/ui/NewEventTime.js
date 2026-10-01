.pragma library

// Time detection for the new event form.
// Accepted in the text: "hh:mm-hh:mm", "hh:mm-hh", "hh-hh:mm", "hh-hh" and a
// lone "hh:mm" (one hour long). The time has to be a separate word.

var rangeRe = /(^|\s)(\d{1,2})(?::(\d{2}))?\s*-\s*(\d{1,2})(?::(\d{2}))?(?=\s|$)/
var singleRe = /(^|\s)(\d{1,2}):(\d{2})(?=\s|$)/
var fieldRe = /^\s*(\d{1,2})(?::(\d{2}))?\s*$/

function validTime(h, m) {
	return h >= 0 && h <= 24 && m >= 0 && m < 60 && !(h === 24 && m > 0)
}

function toTime(hStr, mStr) {
	var h = parseInt(hStr, 10)
	var m = mStr ? parseInt(mStr, 10) : 0
	return validTime(h, m) ? { h: h, m: m } : null
}

// "9" / "9:30" from the form fields, null if empty or invalid
function parseField(text) {
	var match = fieldRe.exec(text || "")
	return match ? toTime(match[1], match[2]) : null
}

// Returns { start, end, title } with start/end as {h, m}, or null
function parseText(text) {
	var match = rangeRe.exec(text)
	var start, end
	if (match) {
		start = toTime(match[2], match[3])
		end = toTime(match[4], match[5])
	} else {
		match = singleRe.exec(text)
		if (!match) {
			return null
		}
		start = toTime(match[2], match[3])
		end = null
	}
	if (!start || (match[4] && !end)) {
		return null
	}
	var title = (text.slice(0, match.index) + match[1] + text.slice(match.index + match[0].length)).replace(/\s+/g, " ").trim()
	return { start: start, end: end, title: title || text.trim() }
}

// start/end {h, m} on the given day -> [startDate, endDate]
// no end = one hour, an end before the start goes to the next day
function toDates(day, start, end) {
	var startDate = new Date(day.getFullYear(), day.getMonth(), day.getDate(), start.h, start.m)
	var endDate
	if (end) {
		endDate = new Date(day.getFullYear(), day.getMonth(), day.getDate(), end.h, end.m)
		if (endDate <= startDate) {
			endDate.setDate(endDate.getDate() + 1)
		}
	} else {
		endDate = new Date(startDate.valueOf() + 60 * 60 * 1000)
	}
	return [startDate, endDate]
}

// Decides what to create. Time in the text wins over the form fields.
// Returns { allDay, start, end, title }, start/end are Dates for timed events.
function resolve(day, text, allDay, fromText, toText) {
	var parsed = parseText(text)
	if (parsed) {
		var dates = toDates(day, parsed.start, parsed.end)
		return { allDay: false, start: dates[0], end: dates[1], title: parsed.title }
	}
	if (!allDay) {
		var from = parseField(fromText)
		if (from) {
			var dates2 = toDates(day, from, parseField(toText))
			return { allDay: false, start: dates2[0], end: dates2[1], title: text.trim() }
		}
	}
	return { allDay: true, start: null, end: null, title: text.trim() }
}

function pad(n) {
	return (n < 10 ? "0" : "") + n
}

function dateString(d) {
	return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
}

// Local time with the UTC offset, e.g. 2026-10-01T10:00:00+02:00
function rfc3339(d) {
	var offset = -d.getTimezoneOffset()
	var sign = offset >= 0 ? "+" : "-"
	offset = Math.abs(offset)
	return dateString(d) + "T" + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":00"
		+ sign + pad(Math.floor(offset / 60)) + ":" + pad(offset % 60)
}
