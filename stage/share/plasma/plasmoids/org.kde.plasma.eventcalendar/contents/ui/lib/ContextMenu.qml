import QtQuick 2.0
import QtQuick.Controls as QQC2

QQC2.Menu {
	id: contextMenu

	signal populate(var contextMenu)

	property var menuItems: []

	function clearMenuItems() {
		menuItems = []
	}

	function newSeperator(parentMenu) {
		return newMenuItem(parentMenu, { separator: true })
	}

	function newMenuItem(parentMenu, properties) {
		var item = menuItemComponent.createObject(contextMenu, properties || {})
		return item
	}

	function newSubMenu(parentMenu, properties) {
		var subMenuItem = newMenuItem(parentMenu || contextMenu, properties)
		var subMenu = Qt.createComponent("ContextMenu.qml").createObject(contextMenu)
		subMenuItem.subMenu = subMenu
		return subMenuItem
	}

	function addMenuItem(item) {
		menuItems.push(item)
	}

	function clearVisualItems() {
		if (typeof clear === "function") {
			clear()
		}
	}

	function addVisualMenuItem(menu, item) {
		if (item.separator) {
			menu.addItem(Qt.createQmlObject("import QtQuick.Controls; MenuSeparator {}", menu))
			return
		}

		var visualItem = Qt.createQmlObject("import QtQuick.Controls; MenuItem {}", menu)
		visualItem.text = item.text || ""
		visualItem.enabled = typeof item.enabled === "undefined" ? true : item.enabled
		if (item.icon) {
			visualItem.icon.name = item.icon
		}
		if (item.subMenu) {
			item.subMenu.rebuildMenu()
			visualItem.menu = item.subMenu
		}
		visualItem.triggered.connect(function() {
			item.clicked()
		})
		menu.addItem(visualItem)
	}

	function rebuildMenu() {
		clearVisualItems()
		for (var i = 0; i < menuItems.length; i++) {
			addVisualMenuItem(contextMenu, menuItems[i])
		}
	}

	function show(x, y) {
		clearMenuItems()
		populate(contextMenu)
		rebuildMenu()
		if (menuItems.length > 0) {
			contextMenu.x = x
			contextMenu.y = y
			open()
		}
	}

	property var menuItemComponent: Component {
		MenuItem {}
	}
}
