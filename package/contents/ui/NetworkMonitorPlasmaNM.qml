import QtQuick 2.0
import org.kde.plasma.networkmanagement as PlasmaNM

PlasmaNM.NetworkStatus {
	id: plasmaNMStatus
	// onActiveConnectionsChanged: logger.debug('NetworkStatus.activeConnections', activeConnections)
	onConnectivityChanged: function(connectivity) {
		logger.debug('NetworkStatus.connectivity', connectivity)
	}
	Component.onCompleted: {
		// logger.debug('NetworkStatus.activeConnections', activeConnections)
		logger.debug('NetworkStatus.connectivity', connectivity)
	}
}
