import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

// GidroLog: pitch and roll inclinometers + compass in one column (instead of the artificial horizon)
Rectangle {
    width:  ScreenTools.defaultFontPixelHeight * 10
    height: (_innerRadius * 6) + (_outerMargin * 4)
    radius: _outerRadius
    color:  QGroundControl.globalPalette.window

    property real extraInset:           0
    property real extraValuesWidth:     _outerRadius

    property real _outerMargin: (width * 0.05) / 2
    property real _outerRadius: width / 2
    property real _innerRadius: _outerRadius - _outerMargin
    property var  _vehicle:     globals.activeVehicle

    // Prevent all clicks from going through to lower layers
    DeadMouseArea {
        anchors.fill: parent
    }

    Column {
        anchors.centerIn:   parent
        spacing:            _outerMargin

        GidroLogInclinometer {
            size:       _innerRadius * 2
            isPitch:    true
            angle:      _vehicle ? _vehicle.pitch.rawValue : NaN
        }

        GidroLogInclinometer {
            size:       _innerRadius * 2
            isPitch:    false
            angle:      _vehicle ? _vehicle.roll.rawValue : NaN
        }

        QGCCompassWidget {
            size:       _innerRadius * 2
            vehicle:    _vehicle
        }
    }
}
