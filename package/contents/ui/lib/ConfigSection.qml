// Version 3
//
// Plasma 6 KCM-style config pages tend to avoid heavy GroupBox frames.
// Keep "sections" as a lightweight layout wrapper with good spacing.

import QtQuick 2.0
import QtQuick.Layouts 1.0
import org.kde.kirigami as Kirigami

ColumnLayout {
	id: configSection
	Layout.fillWidth: true
	spacing: Kirigami.Units.smallSpacing

	// Keep compatibility with legacy usage that set `title:` on the old GroupBox.
	property alias title: heading.text

	default property alias _contentChildren: content.data

	Kirigami.Heading {
		id: heading
		visible: text.length > 0
		level: 4
		Layout.fillWidth: true
	}

	Kirigami.Separator {
		visible: heading.visible
		Layout.fillWidth: true
	}

	ColumnLayout {
		id: content
		Layout.fillWidth: true
		spacing: Kirigami.Units.smallSpacing

		// Workaround for crash when using default on a Layout.
		// https://bugreports.qt.io/browse/QTBUG-52490
		Component.onDestruction: {
			while (children.length > 0) {
				children[children.length - 1].parent = configSection
			}
		}
	}
}

