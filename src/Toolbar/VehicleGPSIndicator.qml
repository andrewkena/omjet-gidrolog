import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

GPSIndicator {
    objectName:     "toolbar_gpsIndicator"
    property bool showIndicator: _activeVehicle.gps.telemetryAvailable
    showCoordinates: true   // GidroLog

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
}
