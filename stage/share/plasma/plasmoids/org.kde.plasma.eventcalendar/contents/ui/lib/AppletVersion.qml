import QtQuick 2.0
import QtQuick.Controls

import "Requests.js" as Requests

Item {
	implicitWidth: label.implicitWidth
	implicitHeight: label.implicitHeight

	property string version: "?"

	Label {
		id: label
		text: i18n("<b>Version:</b> %1", version)
	}

	Component.onCompleted: {
		Requests.getAppletVersion(function(err, v) {
			if (!err && v) {
				version = v
			}
		})
	}
}
