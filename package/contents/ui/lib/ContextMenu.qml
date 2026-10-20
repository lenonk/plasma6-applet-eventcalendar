import QtQuick 2.0
import QtQuick.Controls as QQC2

QQC2.Menu {
	id: contextMenu

	signal populate(var contextMenu)

	property var menuItems: []
	property var ownedObjects: [] // MenuItem models and submenus created by this menu

	function clearMenuItems() {
		for (var i = 0; i < ownedObjects.length; i++) {
			var obj = ownedObjects[i]
			if (typeof obj.clearVisualItems === "function") {
				obj.clearVisualItems()
			}
			obj.destroy()
		}
		ownedObjects = []
		menuItems = []
	}

	function newSeperator(parentMenu) {
		return newMenuItem(parentMenu, { separator: true })
	}

	function newMenuItem(parentMenu, properties) {
		var item = menuItemComponent.createObject(contextMenu, properties || {})
		ownedObjects.push(item)
		return item
	}

	function newSubMenu(parentMenu, properties) {
		var subMenuItem = newMenuItem(parentMenu || contextMenu, properties)
		var subMenu = Qt.createComponent("ContextMenu.qml").createObject(contextMenu)
		ownedObjects.push(subMenu)
		subMenuItem.subMenu = subMenu
		return subMenuItem
	}

	function addMenuItem(item) {
		menuItems.push(item)
	}

	function clearVisualItems() {
		while (count > 0) {
			var first = itemAt(0)
			if (first && first.subMenu) {
				takeMenu(0) // Menu deletes the submenu's own item
			} else {
				var visualItem = takeItem(0)
				if (visualItem) {
					visualItem.destroy()
				}
			}
		}
	}

	function addVisualMenuItem(menu, item) {
		if (item.separator) {
			menu.addItem(Qt.createQmlObject("import QtQuick.Controls; MenuSeparator {}", menu))
			return
		}

		if (item.subMenu) {
			item.subMenu.title = item.text || ""
			item.subMenu.rebuildMenu()
			menu.addMenu(item.subMenu)
			var subMenuItem = menu.itemAt(menu.count - 1)
			if (subMenuItem) {
				subMenuItem.enabled = item.enabled
				if (item.icon) {
					subMenuItem.icon.name = item.icon
				}
			}
			return
		}

		var visualItem = Qt.createQmlObject("import QtQuick.Controls; MenuItem {}", menu)
		visualItem.text = item.text || ""
		visualItem.enabled = item.enabled
		if (item.icon) {
			visualItem.icon.name = item.icon
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
		clearVisualItems()
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
