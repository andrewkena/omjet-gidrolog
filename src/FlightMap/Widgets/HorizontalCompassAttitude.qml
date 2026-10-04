import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

// GidroLog: pitch and roll inclinometers + compass in one row (instead of the artificial horizon)
Rectangle {
    id:     control
    width:  Math.min(_defaultWidth, _maxWidth)
    height: _outerRadius * 2
    radius: _outerRadius
    color:  qgcPal.window

    property real extraInset:           0
    property real extraValuesWidth:     _outerRadius

    property real   _defaultWidth:      mainWindow.width * 0.3
    property real   _maxWidth:          ScreenTools.defaultFontPixelHeight * 22.5
    property real   _innerRadius:       (width - (_topBottomMargin * 4)) / 6
    property real   _outerRadius:       _innerRadius + _topBottomMargin
    property real   _topBottomMargin:   (width * 0.05) / 3
    property var    _vehicle:           globals.activeVehicle

    DeadMouseArea { anchors.fill: parent }

    QGCPalette { id: qgcPal }

    Row {
        anchors.centerIn:   parent
        spacing:            control._topBottomMargin

        GidroLogInclinometer {
            size:       control._innerRadius * 2
            isPitch:    true
            angle:      control._vehicle ? control._vehicle.pitch.rawValue : NaN
        }

        GidroLogInclinometer {
            size:       control._innerRadius * 2
            isPitch:    false
            angle:      control._vehicle ? control._vehicle.roll.rawValue : NaN
        }

        QGCCompassWidget {
            size:       control._innerRadius * 2
            vehicle:    control._vehicle
        }
    }
}
