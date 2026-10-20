import os, sys
import datetime
from icalendar import Calendar
from dateutil.rrule import rrulestr, rruleset
import json
import urllib.parse
import urllib.request

debugging=False
def debug(*args):
	if debugging:
		print(*args, file=sys.stderr)

def isDateTime(dt):
	return isinstance(dt, datetime.datetime)

def dateToJson(dt, allDay):
	if allDay:
		# { "date": "2010-08-04" }
		return { 'date': (dt.date() if isDateTime(dt) else dt).isoformat() }
	else:
		# { "dateTime": "2014-10-02T18:00:00+00:00" }
		return { 'dateTime': dt.isoformat() }

def ensureDateTime(dt):
	# datetime is a subclass of date, so test for datetime first.
	if isDateTime(dt):
		return dt
	return datetime.datetime.combine(dt, datetime.time.min)

def toWall(dt, tz):
	# Naive wall-clock time in tz; None means floating (system local) time.
	if not isDateTime(dt):
		return datetime.datetime.combine(dt, datetime.time.min)
	if dt.tzinfo is None:
		return dt
	if tz is None:
		return dt.astimezone().replace(tzinfo=None)
	return dt.astimezone(tz).replace(tzinfo=None)

def eventDuration(event, dtstart):
	if 'DTEND' in event:
		return ensureDateTime(event['DTEND'].dt) - ensureDateTime(dtstart)
	if 'DURATION' in event:
		return event['DURATION'].dt
	# RFC 5545: a DATE start lasts one day, a DATE-TIME start is instantaneous.
	return datetime.timedelta(days=0 if isDateTime(dtstart) else 1)

def listify(value):
	if value is None:
		return []
	return value if isinstance(value, list) else [value]

def occurrences(event, startTime, endTime, overrides):
	# Expand in the event's wall-clock time so instances keep their hour across DST.
	dtstart = event['DTSTART'].dt
	tz = dtstart.tzinfo if isDateTime(dtstart) else None
	base = toWall(dtstart, tz)
	duration = eventDuration(event, dtstart)
	if tz is not None:
		startTime = toWall(startTime.astimezone(), tz)
		endTime = toWall(endTime.astimezone(), tz)

	if 'RRULE' not in event:
		starts = [base]
	else:
		rules = rruleset()
		for rrule in listify(event.get('RRULE')):
			rule = rrulestr(rrule.to_ical().decode(), dtstart=base, ignoretz=True)
			untils = rrule.get('UNTIL')
			if untils:
				until = untils[0]
				until = toWall(until, tz) if isDateTime(until) else datetime.datetime.combine(until, datetime.time.max)
				rule = rule.replace(until=until)
			rules.rrule(rule)
		for prop in listify(event.get('RDATE')):
			for d in prop.dts:
				if not isinstance(d.dt, tuple): # Skip PERIOD values.
					rules.rdate(toWall(d.dt, tz))
		for prop in listify(event.get('EXDATE')):
			for d in prop.dts:
				rules.exdate(toWall(d.dt, tz))
		starts = rules.between(startTime - duration, endTime, inc=True)[:1000]

	for start in starts:
		end = start + duration
		# Keep it if it starts before endTime and ends after startTime.
		if start > endTime:
			continue
		if (end <= startTime) if end > start else (start < startTime):
			continue
		if start in overrides:
			continue # Replaced by a RECURRENCE-ID instance.
		if tz is not None:
			start = start.replace(tzinfo=tz)
			end = end.replace(tzinfo=tz)
		yield start, end

def eventToJson(event, start, end, allDay):
	item = {}
	item['kind'] = 'calendar#event'
	item['etag'] = '\"0123456789012345\"'
	item['iCalUID'] = str(event.get('UID', ''))
	item['id'] = "ics_{}_{}_{}".format(item['iCalUID'], start.isoformat(), end.isoformat())
	item['status'] = 'confirmed'
	item['htmlLink'] = ''
	if 'CREATED' in event:
		item['created'] = event['CREATED'].dt.isoformat()
	if 'LAST-MODIFIED' in event:
		item['updated'] = event['LAST-MODIFIED'].dt.isoformat()
	item['summary'] = str(event.get('SUMMARY', ''))
	if 'LOCATION' in event:
		item['location'] = str(event['LOCATION'])
	if 'DESCRIPTION' in event:
		item['description'] = str(event['DESCRIPTION'])
	item['start'] = dateToJson(start, allDay)
	item['end'] = dateToJson(end, allDay)
	return item

class CalendarManager:
	def __init__(self, url):
		self.url = url
		self.cal = None

	def read(self):
		self.cal = Calendar.from_ical(readUrl(self.url))

	@property
	def events(self):
		return self.cal.walk('vevent')

	def query(self, startTime, endTime):
		events = [e for e in self.events if 'DTSTART' in e]
		# Instances moved or edited by a RECURRENCE-ID entry, keyed by UID.
		overrides = {}
		for event in events:
			if 'RECURRENCE-ID' in event:
				uid = str(event.get('UID', ''))
				overrides.setdefault(uid, []).append(event['RECURRENCE-ID'].dt)

		for event in events:
			if str(event.get('STATUS', '')).upper() == 'CANCELLED':
				continue
			dtstart = event['DTSTART'].dt
			allDay = not isDateTime(dtstart)
			tz = None if allDay else dtstart.tzinfo
			skip = set()
			if 'RRULE' in event:
				skip = set(toWall(d, tz) for d in overrides.get(str(event.get('UID', '')), []))
			try:
				for start, end in occurrences(event, startTime, endTime, skip):
					yield eventToJson(event, start, end, allDay)
			except (ValueError, TypeError) as e:
				sys.stderr.write('Skipping event {}: {}\n'.format(event.get('UID', ''), e))

def readUrl(url):
	parsed = urllib.parse.urlparse(url)
	if parsed.scheme in ('http', 'https', 'webcal', 'webcals'):
		if parsed.scheme.startswith('webcal'):
			url = 'https' + url[len(parsed.scheme):]
		req = urllib.request.Request(url, headers={ 'User-Agent': 'plasma-applet-eventcalendar' })
		with urllib.request.urlopen(req, timeout=30) as sock:
			return sock.read()
	if parsed.scheme == 'file':
		path = urllib.request.url2pathname(parsed.path)
	elif parsed.scheme == '':
		path = os.path.expanduser(url)
	else:
		raise ValueError("Unsupported URL scheme: '{}'".format(parsed.scheme))
	with open(path, 'rb') as f:
		return f.read()

def parseDate(dateStr):
	return datetime.datetime.strptime(dateStr, '%Y-%m-%d')

def argparse_date(s):
	try:
		return parseDate(s)
	except ValueError:
		msg = "Not a valid date: '{0}'.".format(s)
		raise argparse.ArgumentTypeError(msg)

if __name__ == '__main__':
	import argparse

	parser = argparse.ArgumentParser(description="Read an .ics calendar as Google Calendar style JSON")
	parser.add_argument("--url", type=str, required=True, help="Path or URL of the .ics file")
	subparsers = parser.add_subparsers(help='Commands', dest='subcommand')

	query = subparsers.add_parser('query')
	query.add_argument("startTime", type=argparse_date, help="Inclusive starting date in YYYY-MM-DD format")
	query.add_argument("endTime", type=argparse_date, help="Inclusive ending date in YYYY-MM-DD format")

	subparsers.add_parser('create', help="Create an empty local calendar file if it doesn't exist")

	# debugging = True
	if debugging:
		args = parser.parse_args(['--url', 'basic.ics', 'query', '2016-09-15', '2016-09-16'])
	else:
		args = parser.parse_args()

	if args.subcommand == 'create':
		path = os.path.expanduser(args.url)
		if not os.path.exists(path):
			os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
			with open(path, 'w') as f:
				f.write('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Event Calendar//EN\r\nEND:VCALENDAR\r\n')
		sys.exit(0)

	manager = CalendarManager(args.url)
	if args.subcommand == 'query':
		try:
			manager.read()
		except Exception as e:
			sys.stderr.write('Could not read {}: {}\n'.format(args.url, e))
			sys.exit(1)
		# Inclusive end date: include events that start on that day.
		endTime = args.endTime + datetime.timedelta(days=1) - datetime.timedelta(microseconds=1)
		items = list(manager.query(args.startTime, endTime))
		print(json.dumps({ 'items': items }, indent=4))
	else:
		parser.print_usage(sys.stderr)
		sys.exit(2)
