.pragma library

// https://github.com/KDE/plasma-framework/blob/master/src/declarativeimports/calendar/eventpluginsmanager.h
// https://github.com/KDE/plasma-framework/blob/master/src/declarativeimports/calendar/eventpluginsmanager.cpp

function getPluginFilename(pluginPath) {
	if (!pluginPath) {
		return ''
	}
	var pathStr = ("" + pluginPath).trim()
	var filename = pathStr.substr(pathStr.lastIndexOf('/') + 1)
	filename = filename.trim()
	// Plasma 5 often exposed the library filename (eg: holidaysevents.so) while Plasma 6
	// can expose the plugin id/base-name. Normalize to avoid mismatches.
	filename = filename.replace(/\\.so(\\.\\d+)*$/, '')
	// Backward-compat: older versions of this widget stored "holidays" (config UI dir name)
	// instead of the actual plugin id "holidaysevents".
	if (filename === 'holidays') {
		return 'holidaysevents'
	}
	return filename
}

function pluginPathToFilenameList(pluginPathList) {
	var pluginFilenameList = []
	if (!pluginPathList) {
		return pluginFilenameList
	}
	// QML StringList behaves like an array, but guard against accidental string values.
	if (typeof pluginPathList === 'string') {
		pluginPathList = [pluginPathList]
	}
	for (var i = 0; i < pluginPathList.length; i++) {
		var pluginFilename = getPluginFilename(pluginPathList[i])
		if (pluginFilename && pluginFilenameList.indexOf(pluginFilename) == -1) {
			pluginFilenameList.push(pluginFilename)
		}
	}
	return pluginFilenameList
}

function getPluginPath(eventPluginsManager, pluginFilenameA) {
	if (!pluginFilenameA) {
		return null
	}
	if (!eventPluginsManager || !eventPluginsManager.model) {
		// Model not ready yet. Returning the normalized id is better than failing hard,
		// and works on platforms where enabledPlugins accepts ids rather than paths.
		return getPluginFilename(pluginFilenameA)
	}
	if (typeof eventPluginsManager.model.rowCount !== "function" || typeof eventPluginsManager.model.get !== "function") {
		// Plasma 6 model API does not expose ListModel::get(). Try the QAbstractItemModel API.
		if (typeof eventPluginsManager.model.index === "function" && typeof eventPluginsManager.model.data === "function") {
			var needle = getPluginFilename(pluginFilenameA)
			var needleLower = ("" + needle).toLowerCase()
			for (var r = 0; r < eventPluginsManager.model.rowCount(); r++) {
				var idx = eventPluginsManager.model.index(r, 0)
				// Prefer the actual plugin id (Qt.UserRole+1 = 257) in Plasma 6.
				var pluginId2 = eventPluginsManager.model.data(idx, 257)
				var pluginIdNorm2 = getPluginFilename(pluginId2)
				if (needle && needle == pluginIdNorm2) {
					return pluginId2
				}
				// Legacy bug: config stored display names, so allow display -> pluginId mapping.
				var display2 = eventPluginsManager.model.data(idx, 0) // Qt.DisplayRole
				if (display2 && ("" + display2).toLowerCase() === needleLower) {
					return pluginId2
				}
			}
		}
		// As a last resort, return the normalized id; some versions accept ids instead of paths.
		return getPluginFilename(pluginFilenameA)
	}
	for (var i = 0; i < eventPluginsManager.model.rowCount(); i++) {
		var pluginPath = eventPluginsManager.model.get(i, 'pluginPath')
		// console.log('\t\t', i, pluginPath)
		var pluginFilenameB = getPluginFilename(pluginPath)
		if (getPluginFilename(pluginFilenameA) == pluginFilenameB) {
			return pluginPath
		}
	}

	// Plugin not installed
	return getPluginFilename(pluginFilenameA)
}

function pluginFilenameToPathList(eventPluginsManager, pluginFilenameList) {
	if (!eventPluginsManager) {
		return []
	}
	if (!pluginFilenameList) {
		return []
	}
	// QML StringList behaves like an array, but guard against accidental string values.
	if (typeof pluginFilenameList === 'string') {
		pluginFilenameList = [pluginFilenameList]
	}
	// console.log('eventPluginsManager', eventPluginsManager)
	// console.log('eventPluginsManager.model', eventPluginsManager.model)
	// console.log('eventPluginsManager.model.rowCount', eventPluginsManager.model.rowCount())
	var pluginPathList = []
	for (var i = 0; i < pluginFilenameList.length; i++) {
		var pluginFilename = getPluginFilename(pluginFilenameList[i])
		// console.log('\t\t', i, pluginFilename)
		var pluginPath = getPluginPath(eventPluginsManager, pluginFilename)
		// If we cannot map to a full path (Plasma 6 exposes different model APIs),
		// fall back to the normalized id and let the C++ side resolve it.
		pluginPath = pluginPath || pluginFilename
		if (!pluginPath) {
			continue
		}
		if (pluginPathList.indexOf(pluginPath) == -1) {
			pluginPathList.push(pluginPath)
		}
	}
	// console.log('pluginFilenameList', pluginFilenameList)
	// console.log('pluginPathList', pluginPathList)
	return pluginPathList
}

function populateEnabledPluginsByFilename(eventPluginsManager, pluginFilenameList) {
	var pluginPathList = pluginFilenameToPathList(eventPluginsManager, pluginFilenameList)
	if (eventPluginsManager && typeof eventPluginsManager.populateEnabledPluginsList === "function") {
		// Plasma 5 API
		eventPluginsManager.populateEnabledPluginsList(pluginPathList)
	} else if (eventPluginsManager) {
		// Plasma 6: enabledPlugins is writable and triggers model updates.
		eventPluginsManager.enabledPlugins = pluginPathList
	}
}

function setEnabledPluginsByFilename(eventPluginsManager, pluginFilenameList) {
	var pluginPathList = pluginFilenameToPathList(eventPluginsManager, pluginFilenameList)
	eventPluginsManager.enabledPlugins = pluginPathList
}
