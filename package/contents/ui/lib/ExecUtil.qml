// Version 6

import QtQuick 2.0
import org.kde.plasma.plasma5support as Plasma5Support

	Plasma5Support.DataSource {
		id: executable
		engine: "executable"
		connectedSources: []
		onNewData: function(sourceName, data) {
			var cmd = sourceName
			var exitCode = data["exit code"]
			var exitStatus = data["exit status"]
			var stdout = data["stdout"]
			var stderr = data["stderr"]
		var listener = listeners[cmd]
		if (listener) {
			listener(cmd, exitCode, exitStatus, stdout, stderr)
		}
		exited(cmd, exitCode, exitStatus, stdout, stderr)
		disconnectSource(sourceName) // cmd finished
	}

	signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)

	function trimOutput(stdout) {
		return stdout.replace(/\n/g, ' ').trim()
	}

	property var listeners: ({}) // Empty Map

	// Note that this has not gone under a security audit.
	// You probably shouldn't trust 3rd party input.
	function wrapToken(token) {
		token = "" + token
		// ' => '"'"' to escape the single quotes
		token = token.replace(/\x27/g, "\x27\"\x27\"\x27")
		token = "\'" + token + "\'"
		return token
	}

	// Note that this has not gone under a security audit.
	// You probably shouldn't trust 3rd party input.
	// Some of these might be unnecessary.
	function sanitizeString(str) {
		// Remove NULL (0x00), Ctrl+C (0x03), Ctrl+D (0x04) block of characters
		// Remove quotes ("" and '')
		// Remove DEL
		if (str === undefined || str === null) {
			return ''
		}
		return ('' + str).replace(/[\x00-\x1F\x22\x27\x7F]/g, '')
	}

		function stripQuotes(str) {
			return str.replace(/[\x22\x27]/g, '')
		}

		function urlToLocalPath(url) {
			var s = "" + url
			// Qt.resolvedUrl() returns a file URL for local package resources.
			if (s.indexOf("file://") === 0) {
				s = s.substr("file://".length)
				try {
					return decodeURIComponent(s) // e.g. %20 -> space
				} catch (e) {
					return s // Malformed escape; use as-is
				}
			}
			return s
		}

		function exec(cmd, callback) {
			if (Array.isArray(cmd)) {
				cmd = cmd.map(wrapToken)
				cmd = cmd.join(' ')
		}
		// The engine runs each source name once; pad a duplicate in-flight command so both run.
		while (listeners[cmd] || connectedSources.includes(cmd)) {
			cmd += ' '
		}
		if (typeof callback === 'function') {
			var listener = execCallback.bind(executable, callback)
			listeners[cmd] = listener
		}
		// console.log('cmd', cmd)
		connectSource(cmd)
	}

	function execCallback(callback, cmd, exitCode, exitStatus, stdout, stderr) {
		delete listeners[cmd]
		callback(cmd, exitCode, exitStatus, stdout, stderr)
	}

	//--- Tests
	function test() {
		exec(['notify-send', 'test', '$(notify-send escape1)'])
		exec(['notify-send', 'test', '`notify-send escape2`'])
		exec(['notify-send', 'test', '\'; notify-send escape3;\''])
		exec(['notify-send', 'test', '\\\'; notify-send escape4;\\\''])
	}
	// Component.onCompleted: test()
}
