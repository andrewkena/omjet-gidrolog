import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

// GidroLog: instead of the roll/pitch arcs around the compass - two round inclinometers
// (pitch and roll, like a car inclinometer) to the left of the compass.
Item {
    id:             control
    implicitWidth:  usedByMultipleVehicleList ? _compassDiameter : (_compassDiameter * 3) + (_gaugeSpacing * 2)
    implicitHeight: _compassDiameter

    // Kept for compatibility with FlyViewInstrumentPanel / callers
    property real attitudeSize:                 0
    property real attitudeSpacing:              0
    property real extraInset:                   0
    property real extraValuesWidth:             compassRadius
    property real defaultCompassRadius:         (mainWindow.width * 0.15) / 2
    property real maxCompassRadius:             ScreenTools.defaultFontPixelHeight * 7 / 2
    property real compassRadius:                Math.min(defaultCompassRadius, maxCompassRadius)
    property real compassBorder:                ScreenTools.defaultFontPixelHeight / 2
    property var  vehicle:                      globals.activeVehicle
    property var  qgcPal:                       QGroundControl.globalPalette
    property bool usedByMultipleVehicleList:    false

    property real _compassDiameter: compassRadius * 2
    property real _gaugeSpacing:    ScreenTools.defaultFontPixelWidth / 2

    Row {
        anchors.right:  parent.right
        spacing:        control._gaugeSpacing

        GidroLogInclinometer {
            size:       control._compassDiameter
            isPitch:    true
            angle:      control.vehicle ? control.vehicle.pitch.rawValue : NaN
            visible:    !control.usedByMultipleVehicleList
        }

        GidroLogInclinometer {
            size:       control._compassDiameter
            isPitch:    false
            angle:      control.vehicle ? control.vehicle.roll.rawValue : NaN
            visible:    !control.usedByMultipleVehicleList
        }

        Rectangle {
            width:  control._compassDiameter
            height: width
            radius: width / 2
            color:  qgcPal.window

            QGCCompassWidget {
                size:                       parent.width - compassBorder
                vehicle:                    control.vehicle
                usedByMultipleVehicleList:  control.usedByMultipleVehicleList
                anchors.centerIn:           parent
            }
        }
    }
}
