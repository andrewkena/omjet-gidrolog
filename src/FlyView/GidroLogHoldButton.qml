import QtQuick

import QGroundControl
import QGroundControl.Controls

// GidroLog: control-panel button. With holdRequired the action fires only after holding for holdMs
// (a bar fills while held); otherwise it fires on press. Can be highlighted (active) and can blink red.
Rectangle {
    id:             control
    implicitWidth:  ScreenTools.defaultFontPixelWidth * 17
    implicitHeight: Math.max(ScreenTools.defaultFontPixelHeight * 2.2, buttonLabel.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.8)
    radius:         ScreenTools.defaultFontPixelWidth / 2
    color:          _blinkOn ? "#F44336" : (active ? activeColor : qgcPal.button)
    border.color:   qgcPal.text
    border.width:   1
    opacity:        enabled ? 1.0 : 0.5

    property string text
    property bool   active:         false                   ///< highlighted state (armed / current mode)
    property color  activeColor:    "#4CAF50"   // GidroLog: green from the colour palette
    property bool   holdRequired:   true
    property int    holdMs:         2000
    property bool   blinking:       false

    signal activated()

    property real _progress: 0
    property bool _blinkOn:  false

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    // Hold progress
    Rectangle {
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          parent.width * control._progress
        radius:         parent.radius
        color:          qgcPal.text
        opacity:        0.3
        visible:        control._progress > 0
    }

    QGCLabel {
        id:                 buttonLabel
        anchors.centerIn:   parent
        width:              parent.width - ScreenTools.defaultFontPixelWidth
        horizontalAlignment: Text.AlignHCenter
        wrapMode:           Text.WordWrap      // long Russian labels go to two lines
        text:               control.text
        font.bold:          true
        font.pointSize:     ScreenTools.mediumFontPointSize
        color:              (control.active || control._blinkOn) ? "white" : qgcPal.buttonText
    }

    NumberAnimation {
        id:         holdAnimation
        target:     control
        property:   "_progress"
        from:       0
        to:         1
        duration:   control.holdMs
        onFinished: {
            if (control._progress >= 1) {
                control._progress = 0
                control.activated()
            }
        }
    }

    Timer {
        interval:   250
        repeat:     true
        running:    control.blinking
        onTriggered: control._blinkOn = !control._blinkOn
        onRunningChanged: {
            if (!running) {
                control._blinkOn = false
            }
        }
    }

    MouseArea {
        anchors.fill:   parent
        enabled:        control.enabled

        onPressed: {
            if (control.holdRequired) {
                holdAnimation.restart()
            } else {
                control.activated()
            }
        }
        onReleased: {
            holdAnimation.stop()
            control._progress = 0
        }
        onCanceled: {
            holdAnimation.stop()
            control._progress = 0
        }
    }
}
