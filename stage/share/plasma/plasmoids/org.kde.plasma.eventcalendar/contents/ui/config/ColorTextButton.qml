import QtQuick 2.0
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Button {
	id: colorTextButton
	property int padding: Kirigami.Units.smallSpacing
	implicitWidth: padding + colorTextLabel.implicitWidth + padding
	implicitHeight: padding + colorTextLabel.implicitHeight + padding

	property alias label: colorTextLabel.text

	Label {
		id: colorTextLabel
		anchors.centerIn: parent
		color: Kirigami.Theme.buttonTextColor
	}
}
