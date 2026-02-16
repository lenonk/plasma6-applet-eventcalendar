// Version 5

import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts 1.0
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
		return ("" + str).replace(/["']/g, "")
	}

	function urlToLocalPath(url) {
		var s = "" + (url || "")
		if (s.indexOf("file://") === 0) {
			// Keep behavior predictable for local file URLs picked by FileDialog.
			s = s.substr("file://".length)
			try { s = decodeURIComponent(s) } catch (e) {}
		}
		return stripQuotes(s)
	}

	function shellQuote(token) {
		token = "" + token
		token = token.replace(/'/g, "'\"'\"'")
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
				sfxPathValue = selected
			}
		}
	}
}
