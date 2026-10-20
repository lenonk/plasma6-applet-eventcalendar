// Version 6

import QtQuick 2.0
import QtQml
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts 1.0

RowLayout {
	id: configSound
	property alias label: sfxEnabledCheckBox.text
	property alias sfxEnabledKey: sfxEnabledCheckBox.configKey
	property alias sfxPathKey: sfxPath.configKey

	property alias sfxEnabled: sfxEnabledCheckBox.checked
	property alias sfxPathValue: sfxPath.value
	property alias sfxPathDefaultValue: sfxPath.defaultValue

	function fileUrlToPath(url) {
		var s = "" + (url || "")
		if (s.indexOf("file://") === 0) {
			s = s.substr("file://".length)
			try { s = decodeURIComponent(s) } catch (e) {}
		}
		return s
	}

	// notification.py resolves sound names and the sound theme, so previews match notifications.
	ExecUtil { id: executable }
	readonly property string scriptPath: executable.urlToLocalPath(Qt.resolvedUrl("../../scripts/notification.py"))

	function playSound() {
		var sound = fileUrlToPath(sfxPath.value)
		if (!sound) return
		executable.exec(["python3", scriptPath, "--preview", "--sound=" + sound])
	}

	// Sound names of the Plasma sound theme, loaded on first use.
	property var themeSounds: []
	function showSystemSounds() {
		if (themeSounds.length > 0) {
			systemSoundsMenu.popup()
			return
		}
		executable.exec(["python3", scriptPath, "--list-sounds"], function(cmd, exitCode, exitStatus, stdout, stderr) {
			configSound.themeSounds = ("" + (stdout || "")).split("\n").filter(function(name) { return !!name })
			systemSoundsMenu.popup()
		})
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
		onClicked: configSound.showSystemSounds()
		ToolTip.visible: hovered
		ToolTip.text: i18n("System sounds")

		Menu {
			id: systemSoundsMenu
			Instantiator {
				model: configSound.themeSounds
				delegate: MenuItem {
					text: modelData
					onTriggered: sfxPathValue = modelData
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
				// Store a plain path.
				sfxPathValue = fileUrlToPath(selected)
			}
		}
	}
}
