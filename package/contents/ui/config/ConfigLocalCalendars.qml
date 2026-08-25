import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.plasma.PimCalendars

import "../lib"
import "../calendars/PlasmaCalendarUtils.js" as PlasmaCalendarUtils

ConfigPage {
	id: page

	// PimCalendar / PimEventsConfig roles. Kept in sync with pimcalendarsmodel.h.
	readonly property int roleCollectionId: Qt.UserRole + 1
	readonly property int roleName: Qt.UserRole + 2
	readonly property int roleEnabled: Qt.UserRole + 3
	readonly property int roleChecked: Qt.UserRole + 4
	readonly property int roleIconName: Qt.UserRole + 5

	// PimCalendarsModel is not guaranteed to be available (eg: headless
	// installs without kdepim). Detect that gracefully.
	//
	// PimCalendarsModel wraps an Akonadi::EntityTreeModel populated
	// asynchronously (collectionTreeFetched), so an immediate refresh
	// returns rowCount=0 even though collections exist. We trigger on
	// rowsInserted / modelReset / dataChanged plus a few delayed retries.
	readonly property var pimModel: PimCalendarsModel {
		id: pimModel
		onDataChanged: refreshAll()
		onModelReset: refreshAll()
		onRowsInserted: refreshAll()
	}

	Timer {
		id: readyProbe
		repeat: false
		interval: 250
		onTriggered: page.refreshAll()
	}
	Timer {
		id: readyProbe2
		repeat: false
		interval: 1500
		onTriggered: page.refreshAll()
	}
	Timer {
		id: readyProbe3
		repeat: false
		interval: 4000
		onTriggered: page.refreshAll()
	}

	// Flat list of { id, name, icon, isChecked } for the Repeater delegate.
	property var entries: []
	property bool hasKdepim: false

	function refreshAll() {
		var list = []
		hasKdepim = !!(pimModel && typeof pimModel.rowCount === "function")
		if (hasKdepim) {
			function pushIfCalendar(idx) {
				var akonadiId = pimModel.data(idx, page.roleCollectionId)
				if (typeof akonadiId === "undefined" || akonadiId === null) return
				akonadiId = "" + akonadiId
				var isCalendar = !!pimModel.data(idx, page.roleEnabled)
				if (!isCalendar) return
				var name = pimModel.data(idx, page.roleName) || pimModel.data(idx, 0) || ("Calendar " + akonadiId)
				var icon = pimModel.data(idx, page.roleIconName) || ""
				var isChecked = !!pimModel.data(idx, page.roleChecked)
				list.push({
					id: akonadiId,
					name: name,
					iconName: icon,
					isChecked: isChecked,
				})
			}
			for (var i = 0; i < pimModel.rowCount(); i++) {
				var top = pimModel.index(i, 0)
				pushIfCalendar(top)
				if (pimModel.hasChildren && pimModel.hasChildren(top)) {
					for (var j = 0; j < pimModel.rowCount(top); j++) {
						pushIfCalendar(pimModel.index(j, 0, top))
					}
				}
			}
		}
		entries = list
	}

	function setChecked(id, value) {
		if (!pimModel || typeof pimModel.setChecked !== "function") return
		pimModel.setChecked(parseInt(id, 10), value)
		pimModel.saveConfig()
		// Remember which set is currently enabled so we can detect "user
		// changed something" from the outside (eventModel refresh trigger).
		var ids = []
		for (var i = 0; i < entries.length; i++) {
			var e = entries[i]
			var checkedNow = (e.id === id) ? value : e.isChecked
			if (checkedNow) ids.push(e.id)
		}
		plasmoid.configuration.pimEnabledCalendars = ids
	}

	Component.onCompleted: {
		refreshAll()
		// PimCalendarsModel's initial population is async; probe a few times.
		readyProbe.start()
		readyProbe2.start()
		readyProbe3.start()
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Kirigami.Units.largeSpacing

		ConfigSection {
			title: i18n("Local Calendars")

			ColumnLayout {
				Layout.fillWidth: true
				spacing: Kirigami.Units.smallSpacing

				Kirigami.InlineMessage {
					Layout.fillWidth: true
					type: Kirigami.MessageType.Information
					text: i18n("Toggle which Akonadi/PIM calendars feed this widget via the Plasma PIM Events plugin. Changes are saved immediately and shared with KOrganizer.")
					// Help text for the dedicated user-facing side panel.
				}

				Repeater {
					model: page.entries

					delegate: RowLayout {
						Layout.fillWidth: true
						spacing: Kirigami.Units.smallSpacing

						required property int index
						required property string id
						required property string name
						required property string iconName
						required property bool isChecked

						Kirigami.Icon {
							source: parent.iconName || "x-office-calendar"
							Layout.alignment: Qt.AlignVCenter
							implicitWidth: Kirigami.Units.iconSizes.small
							implicitHeight: implicitWidth
							visible: source !== ""
						}

						QQC2.CheckBox {
							Layout.fillWidth: true
							text: parent.name + "  (" + parent.id + ")"
							checked: parent.isChecked
							onCheckedChanged: page.setChecked(parent.parent.id, checked)
						}
					}
				}

				Kirigami.InlineMessage {
					Layout.fillWidth: true
					visible: !page.hasKdepim
					type: Kirigami.MessageType.Error
					text: i18n("KDE PIM (kdepim-addons) is not installed, so no local calendars are available.")
				}

				Kirigami.InlineMessage {
					Layout.fillWidth: true
					visible: page.hasKdepim && page.entries.length === 0
					type: Kirigami.MessageType.Warning
					text: i18n("No calendar or task collections were found in Akonadi. Add a local or remote calendar in KOrganizer and reload this page.")
				}
			}
		}
	}
}
