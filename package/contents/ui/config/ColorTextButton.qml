import QtQuick 2.0
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Button {
	id: colorTextButton
	readonly property int extraPadding: Kirigami.Units.smallSpacing
	padding: extraPadding
	implicitWidth: extraPadding + colorTextLabel.implicitWidth + extraPadding
	implicitHeight: extraPadding + colorTextLabel.implicitHeight + extraPadding

	property alias label: colorTextLabel.text

	Label {
		id: colorTextLabel
		anchors.centerIn: parent
		color: Kirigami.Theme.textColor
	}
}
