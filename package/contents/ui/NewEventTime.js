.pragma library
.import "Shared.js" as Shared

// Time detection for the new event form.
// At the start of the text: "hh-hh", "hh:mm-hh:mm" (either side may drop :mm) or "hh:mm".
// At the end only forms with a colon, so "Room 3-4" stays text. Hours over 24 are never a time.

var startRe = /^\s*(\d{1,2})(?::(\d{2}))?(?:\s*-\s*(\d{1,2})(?::(\d{2}))?)?(?=\s|$)/
var endRe = /(?:^|\s)(\d{1,2})(?::(\d{2}))?(?:\s*-\s*(\d{1,2})(?::(\d{2}))?)?\s*$/
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

function hasColon(match) {
	return !!(match[2] || match[4])
}

// Returns { start, end, title } with start/end as {h, m}, or null
function parseText(text) {
	var match = startRe.exec(text)
	if (!match || !(match[3] || hasColon(match))) {
		match = endRe.exec(text)
		if (!match || !hasColon(match)) {
			return null
		}
	}
	var start = toTime(match[1], match[2])
	var end = match[3] ? toTime(match[3], match[4]) : null
	if (!start || (match[3] && !end)) {
		return null
	}
	var title = (text.slice(0, match.index) + " " + text.slice(match.index + match[0].length)).replace(/\s+/g, " ").trim()
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

// Decides what to create. A time in the text wins over the form fields.
// Returns null when "All day" is ticked and the text has no time (the backend
// decides, e.g. Google quickAdd), { error: "from" | "to" } for a bad field,
// else { start, end, title } with Dates.
function resolve(day, text, allDay, fromText, toText) {
	var parsed = parseText(text)
	if (parsed) {
		var dates = toDates(day, parsed.start, parsed.end)
		return { start: dates[0], end: dates[1], title: parsed.title }
	}
	if (allDay) {
		return null
	}
	var from = parseField(fromText)
	if (!from) {
		return { error: "from" }
	}
	var to = null
	if ((toText || "").trim()) {
		to = parseField(toText)
		if (!to) {
			return { error: "to" }
		}
	}
	var fieldDates = toDates(day, from, to)
	return { start: fieldDates[0], end: fieldDates[1], title: text.trim() }
}

function pad(n) {
	return (n < 10 ? "0" : "") + n
}

// Local time with the UTC offset, e.g. 2026-10-01T10:00:00+02:00
function rfc3339(d) {
	var offset = -d.getTimezoneOffset()
	var sign = offset >= 0 ? "+" : "-"
	offset = Math.abs(offset)
	return Shared.localeDateString(d) + "T" + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":00"
		+ sign + pad(Math.floor(offset / 60)) + ":" + pad(offset % 60)
}
