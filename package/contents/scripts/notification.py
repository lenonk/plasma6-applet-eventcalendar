#!/usr/bin/python3
import os, sys
import argparse
import subprocess
import time
import urllib.parse
from enum import Enum, IntEnum
from ctypes import *

import gi
gi.require_version('GLib', '2.0')
gi.require_version('Notify', '0.7')
from gi.repository import GLib, Notify



#---
# Recreate canberra-gtk-play in Python
#   https://git.0pointer.net/libcanberra.git/tree/src/canberra-gtk-play.c
# Based on Dave Barry's <dave@psax.org> pycanberra under LGPL 2.1
#   https://github.com/totdb/pycanberra/blob/master/pycanberra.py
libcanberra = None
try:
	libcanberra = CDLL("libcanberra.so.0")
except:
	sys.stderr.write('libcanberra not found\n')

def convertArgs(args):
	return (
		arg.encode("utf-8") if isinstance(arg, str) else arg
		for arg in args
	)

ca_context = c_void_p

class Canberra:
	@staticmethod
	def installed():
		return libcanberra is not None

	class Code(IntEnum):
		SUCCESS = 0
		ERROR_NOTSUPPORTED = -1
		ERROR_INVALID = -2
		ERROR_STATE = -3
		ERROR_OOM = -4
		ERROR_NODRIVER = -5
		ERROR_SYSTEM = -6
		ERROR_CORRUPT = -7
		ERROR_TOOBIG = -8
		ERROR_NOTFOUND = -9
		ERROR_DESTROYED = -10
		ERROR_CANCELED = -11
		ERROR_NOTAVAILABLE = -12
		ERROR_ACCESS = -13
		ERROR_IO = -14
		ERROR_INTERNAL = -15
		ERROR_DISABLED = -16
		ERROR_FORKED = -17
		ERROR_DISCONNECTED = -18
		ERROR_MAX = -19

	class Prop(bytes, Enum):
		EVENT_ID = b'event.id'
		EVENT_DESCRIPTION = b'event.description'
		MEDIA_FILENAME = b'media.filename'
		APPLICATION_NAME = b'application.name'
		XDG_THEME_NAME = b'canberra.xdg-theme.name'

	def __init__(self):
		self.context = ca_context()
		self.playId = 1
		libcanberra.ca_context_create(byref(self.context))

	def play(self, *props):
		res = libcanberra.ca_context_play(
			self.context,
			self.playId,
			*convertArgs(props),
			None, # Must end with NULL to mark end of props
		)
		if res != Canberra.Code.SUCCESS:
			raise Exception(Canberra.Code(res), "Error playing", props)

	def waitUntilDone(self, timeout=30):
		playing = c_int(1)
		deadline = time.monotonic() + timeout
		while time.monotonic() < deadline:
			res = libcanberra.ca_context_playing(self.context, self.playId, byref(playing))
			if res != Canberra.Code.SUCCESS or not playing.value:
				return
			time.sleep(0.05)

	def playEvent(self, eventId, *props):
		props += (Canberra.Prop.EVENT_ID, eventId)
		self.play(*props)

	def playFile(self, filename, *props):
		props += (Canberra.Prop.MEDIA_FILENAME, filename)
		self.play(*props)


#---
# Plasma's Notification server doesn't support sounds,
# the KNotify manually plays sounds instead. So we manually
# play them with libcanberra. We can't use canberra-gtk-play since
# it requires the gnome-session-canberra package in Ubuntu,
# which is not installed by default.
FALLBACK_SOUND_ID = 'message-new-instant'
SOUND_EXTENSIONS = ('.oga', '.ogg', '.wav')

def readSoundTheme(path):
	group = None
	try:
		with open(path, encoding='utf-8') as f:
			for line in f:
				line = line.strip()
				if line.startswith('['):
					group = line
				elif group == '[Sounds]' and '=' in line:
					key, value = line.split('=', 1)
					if key.strip() == 'Theme':
						return value.strip()
	except OSError:
		pass
	return ''

# The sound theme picked in System Settings: user kdeglobals, then the system one (Plasma 6 default: ocean).
def kdeSoundTheme():
	configHome = os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config')
	configDirs = (os.environ.get('XDG_CONFIG_DIRS') or '/etc/xdg').split(':')
	for configDir in [configHome] + configDirs:
		theme = readSoundTheme(os.path.join(configDir, 'kdeglobals'))
		if theme:
			return theme
	return 'ocean'

# Where a theme's sounds live, freedesktop last (libcanberra falls back to it too).
def soundThemeDirs(theme):
	dataHome = os.environ.get('XDG_DATA_HOME') or os.path.expanduser('~/.local/share')
	dataDirs = (os.environ.get('XDG_DATA_DIRS') or '/usr/local/share:/usr/share').split(':')
	themes = [theme] if theme == 'freedesktop' else [theme, 'freedesktop']
	return [os.path.join(d, 'sounds', t, 'stereo') for t in themes for d in [dataHome] + dataDirs if d]

def findSoundFile(name, theme):
	for soundDir in soundThemeDirs(theme):
		for ext in SOUND_EXTENSIONS:
			path = os.path.join(soundDir, name + ext)
			if os.path.isfile(path):
				return path
	return None

def listSounds(theme):
	names = set()
	for soundDir in soundThemeDirs(theme):
		try:
			for filename in os.listdir(soundDir):
				name, ext = os.path.splitext(filename)
				if ext in SOUND_EXTENSIONS:
					names.add(name)
		except OSError:
			pass
	return sorted(names)

# A file path or file:// URL, or a sound name from the XDG sound theme.
def resolveSound(sound):
	if sound.startswith('file://'):
		sound = urllib.parse.unquote(sound[len('file://'):])
	if sound.startswith('/') and not os.path.isfile(sound):
		# Eg: the old Oxygen default, which Plasma 6 no longer ships.
		sys.stderr.write('sound file not found, using {}: {}\n'.format(FALLBACK_SOUND_ID, sound))
		sound = FALLBACK_SOUND_ID
	return sound

# Returns the player process when libcanberra could not play it.
def playSound(args, wait=False):
	sound = resolveSound(args.sound)
	theme = kdeSoundTheme()

	if Canberra.installed():
		try:
			canberra = Canberra()
			props = [
				Canberra.Prop.EVENT_DESCRIPTION, args.appName,
				Canberra.Prop.APPLICATION_NAME, args.appName,
				Canberra.Prop.XDG_THEME_NAME, theme,
			]
			if sound.startswith('/'):
				canberra.playFile(sound, *props)
			else:
				canberra.playEvent(sound, *props)
			if wait:
				canberra.waitUntilDone()
			return None
		except Exception as e:
			sys.stderr.write('libcanberra: {}\n'.format(e))

	# No libcanberra: play the file with PipeWire or PulseAudio.
	path = sound if sound.startswith('/') else findSoundFile(sound, theme)
	if not path:
		sys.stderr.write('sound not found: {}\n'.format(sound))
		return None
	for player in ('pw-play', 'paplay'):
		try:
			proc = subprocess.Popen([player, path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
		except OSError:
			continue
		if not wait:
			return proc
		if proc.wait() == 0:
			return None
	sys.stderr.write('could not play sound: {}\n'.format(path))
	return None


#---
def notify(args):
	sfxProc = None

	#--- Notification
	# https://notify2.readthedocs.io/en/latest/
	loop = GLib.MainLoop()
	Notify.init(args.appName)
	# print(Notify.get_server_caps())

	n = Notify.Notification.new(
		args.summary,
		args.message,
		icon=args.icon,
	)

	# Note: EXPIRES_DEFAULT = -1, EXPIRES_NEVER = 0
	n.set_timeout(args.timeout)

	def on_action(notification, action, *user_data):
		sys.stdout.write(' '.join([action, *user_data]) + '\n')
		if sfxProc:
			sfxProc.terminate()
		loop.quit()

	def closed(notification):
		on_action(notification, "closed")

	n.connect("closed", closed)
	n.add_action("default", "default", on_action)
	if args.actions:
		for action in args.actions:
			actionId, actionLabel = action.split(',', 1)
			n.add_action(actionId, actionLabel, on_action)
	n.show()

	#--- Sound
	if args.sound:
		sfxProc = playSound(args)

	loop.run()

def main():
	parser = argparse.ArgumentParser(prog='notification.py', description='Notifications with sound effects and actions.')
	parser.add_argument('summary', nargs='?', default='')
	parser.add_argument('message', nargs='?', default='')
	parser.add_argument('--icon', default='')
	parser.add_argument('--app-name', dest='appName', default='Event Calendar')
	parser.add_argument('--sound')
	parser.add_argument('--loop', type=int, default=0)
	parser.add_argument('--timeout', type=int, default=Notify.EXPIRES_DEFAULT)
	parser.add_argument('--action', dest='actions', action='append')
	parser.add_argument('--metadata')
	# For the config page: play --sound and exit, or print the theme's sound names.
	parser.add_argument('--preview', action='store_true')
	parser.add_argument('--list-sounds', dest='listSounds', action='store_true')


	try:
		args = parser.parse_args()
		if args.listSounds:
			print('\n'.join(listSounds(kdeSoundTheme())))
		elif args.preview:
			if args.sound:
				playSound(args, wait=True)
		else:
			notify(args)
	except KeyboardInterrupt:
		pass
	except Exception as e:
		sys.stderr.write('{}\n'.format(e))
		parser.print_help()

def test():
	notify(argparse.Namespace(
		summary='Summary',
		message='Message',
		icon='plasma',
		appName='Plasma',
		sound='complete',
		loop=False,
		actions=[
			'ok,Ok',
			'cancel,Cancel',
		],
	))

if __name__ == '__main__':
	main()
	# test()


