// Version 5

import QtQuick 2.0
import QtQml
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts 1.0
import Qt.labs.folderlistmodel
import org.kde.plasma.plasma5support as Plasma5Support

RowLayout {
	id: configSound
	property alias label: sfxEnabledCheckBox.text
	property alias sfxEnabledKey: sfxEnabledCheckBox.configKey
	property alias sfxPathKey: sfxPath.configKey

	property alias sfxEnabled: sfxEnabledCheckBox.checked
	property alias sfxPathValue: sfxPath.value
	property alias sfxPathDefaultValue: sfxPath.defaultValue

	function stripQuotes(str) {
		var s = "" + str
		s = s.split("\"").join("")
		s = s.split("'").join("")
		return s
	}

	function fileUrlToPath(url) {
		var s = "" + (url || "")
		if (s.indexOf("file://") === 0) {
			s = s.substr("file://".length)
			try { s = decodeURIComponent(s) } catch (e) {}
		}
		return s
	}

	function urlToLocalPath(url) {
		return stripQuotes(fileUrlToPath(url))
	}

	function shellQuote(token) {
		token = "" + token
		token = token.replace(/\x27/g, "'\"'\"'")
		return "'" + token + "'"
	}

	function uniqueCmd(cmd) {
		var cmd2 = cmd
		for (var i = 0; i < 10; i++) {
			if (executable.connectedSources.indexOf(cmd2) !== -1) {
				cmd2 += " "
			}
		}
		return cmd2
	}

	function playSound() {
		var localPath = urlToLocalPath(sfxPath.value)
		if (!localPath) return
		var quoted = shellQuote(localPath)
		if (localPath.indexOf("/") !== 0) {
			// A sound name from the XDG sound theme, eg: message-new-instant
			var fallback = "f=$(ls /usr/share/sounds/" + systemSounds.themeName + "/stereo/" + quoted + ".* /usr/share/sounds/freedesktop/stereo/" + quoted + ".* 2>/dev/null | grep -v '[.]license$' | head -n 1)"
			executable.connectSource(uniqueCmd("canberra-gtk-play -i " + quoted + " >/dev/null 2>&1"
				+ " || { " + fallback + "; [ -n \"$f\" ] && { pw-play \"$f\" || paplay \"$f\"; }; } >/dev/null 2>&1"))
			return
		}
		var cmd = "paplay " + quoted + " >/dev/null 2>&1"
			+ " || pw-play " + quoted + " >/dev/null 2>&1"
			+ " || aplay " + quoted + " >/dev/null 2>&1"
			+ " || ffplay -nodisp -autoexit -loglevel error " + quoted + " >/dev/null 2>&1"
		executable.connectSource(uniqueCmd(cmd))
	}

	Plasma5Support.DataSource {
		id: executable
		engine: "executable"
		connectedSources: []
		onNewData: function(sourceName, data) {
			disconnectSource(sourceName)
		}
	}

	// Sounds of the Plasma sound theme, offered by name so they follow the theme.
	FolderListModel {
		id: systemSounds
		property string themeName: "ocean"
		folder: "file:///usr/share/sounds/" + themeName + "/stereo"
		nameFilters: ["*.oga", "*.ogg", "*.wav"]
		showDirs: false
		onStatusChanged: {
			if (status === FolderListModel.Ready && count === 0 && themeName !== "freedesktop") {
				themeName = "freedesktop"
			}
		}
	}

	spacing: 0
	ConfigCheckBox {
		id: sfxEnabledCheckBox
	}
	Button {
		icon.name: "media-playback-start-symbolic"
		enabled: sfxEnabled && !!sfxPath.value
		onClicked: playSound()
	}
	ConfigString {
		id: sfxPath
		enabled: sfxEnabled
		Layout.fillWidth: true
	}
	Button {
		icon.name: "preferences-desktop-sound"
		enabled: sfxEnabled
		onClicked: systemSoundsMenu.popup()
		ToolTip.visible: hovered
		ToolTip.text: i18n("System sounds")

		Menu {
			id: systemSoundsMenu
			Instantiator {
				model: systemSounds
				delegate: MenuItem {
					text: fileBaseName
					onTriggered: sfxPathValue = fileBaseName
				}
				onObjectAdded: function(index, object) { systemSoundsMenu.insertItem(index, object) }
				onObjectRemoved: function(index, object) { systemSoundsMenu.removeItem(object) }
			}
		}
	}
	Button {
		icon.name: "folder-symbolic"
		enabled: sfxEnabled
		onClicked: sfxPathDialog.open()

		FileDialog {
			id: sfxPathDialog
			title: i18n("Choose a sound effect")
			currentFolder: '/usr/share/sounds'
			nameFilters: [
				i18n("Sound files (%1)", "*.wav *.mp3 *.oga *.ogg"),
				i18n("All files (%1)", "*"),
			]
			onAccepted: {
				var selected = ""
				if (typeof selectedFile !== "undefined" && selectedFile) {
					selected = selectedFile
				} else if (typeof fileUrl !== "undefined" && fileUrl) {
					selected = fileUrl
				}
				// Store a plain path; notification.py does not decode file URLs.
				sfxPathValue = fileUrlToPath(selected)
			}
		}
	}
}
