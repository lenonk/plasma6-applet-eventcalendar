import QtQuick 2.0

QtObject {
	property string text: ""
	property string icon: ""
	property bool enabled: true
	property bool separator: false
	property var subMenu: null
	signal clicked()
}
