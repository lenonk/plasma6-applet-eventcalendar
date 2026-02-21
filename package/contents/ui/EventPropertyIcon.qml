import QtQuick 2.0
import QtQuick.Layouts 1.1
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kirigami.primitives as KirigamiPrimitives

ColumnLayout {
	id: eventDialogIcon
	Layout.fillHeight: true

	property alias source: iconItem.source
	property int size: Kirigami.Units.iconSizes.smallMedium

	KirigamiPrimitives.Icon {
		id: iconItem
		Layout.alignment: Qt.AlignVCenter

		implicitWidth: eventDialogIcon.size
		implicitHeight: eventDialogIcon.size
	}
}
