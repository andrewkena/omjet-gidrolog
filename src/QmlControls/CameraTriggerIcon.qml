/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.Controls

/// Marks camera trigger (shutter) points on the map (both engines)
/// GidroLog: solid red dot instead of the grey camera glyph
Rectangle {
    width:          _radius * 2
    height:         _radius * 2
    radius:         _radius
    color:          "#E53935"
    border.color:   "#7F0000"
    border.width:   1
    antialiasing:   true

    readonly property real _radius: ScreenTools.defaultFontPixelHeight * 0.3
}
