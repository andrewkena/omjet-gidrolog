import QtQuick

import QGroundControl
import QGroundControl.Controls

// GidroLog: boat symbol in the compass instead of the red arrow
Image {
    id:                 control
    anchors.centerIn:   parent
    width:              compassSize * 0.42
    height:             width
    source:             "/qmlimages/vehicleBoatOpaque.svg"
    sourceSize.width:   width
    sourceSize.height:  height
    fillMode:           Image.PreserveAspectFit
    mipmap:             true
    smooth:             true

    property real compassSize
    property real heading
    property bool simplified:    false

    transform: Rotation {
        origin.x:   control.width / 2
        origin.y:   control.height / 2
        angle:      heading
    }
}
