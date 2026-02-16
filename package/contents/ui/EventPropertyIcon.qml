import QtQuick 2.0
import QtQuick.Layouts 1.1
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kirigami.primitives as KirigamiPrimitives

ColumnLayout {
	id: eventDialogIcon
	Layout.fillHeight: true
	readonly property var units: Kirigami.Units

	property alias source: iconItem.source
	property int size: units.iconSizes.smallMedium

	KirigamiPrimitives.Icon {
		id: iconItem
		Layout.alignment: Qt.AlignVCenter

		implicitWidth: eventDialogIcon.size
		implicitHeight: eventDialogIcon.size
	}
}
