import QtQuick

import QGroundControl
import QGroundControl.Controls

// GidroLog: round inclinometer (like a car pitch/roll gauge).
// A boat silhouette with its waterline rotates by the angle against a fixed +/-40 deg scale:
// yellow = positive (nose up / right side down), blue = negative.
Item {
    id:     gauge
    width:  size
    height: size

    property real   size:       ScreenTools.defaultFontPixelHeight * 7
    property real   angle:      0           ///< degrees
    property bool   isPitch:    true        ///< true: pitch (side view), false: roll (rear view)
    property string caption:    isPitch ? qsTr("ТАНГАЖ") : qsTr("КРЕН")

    readonly property real _maxScale:   40
    readonly property color _yellow:    "#FFD54F"
    readonly property color _blue:      "#29B6F6"
    property var qgcPal:                QGroundControl.globalPalette

    // Visual rotation, limited to the scale
    readonly property real _shownAngle: isNaN(angle) ? 0 : Math.max(-_maxScale - 5, Math.min(_maxScale + 5, angle))

    Rectangle {
        anchors.fill:   parent
        radius:         width / 2
        color:          "#12161B"
        border.color:   qgcPal.text
        border.width:   1
    }

    // Fixed scale: arcs and ticks every 10 deg on both sides, labels on the left
    Canvas {
        id:             scaleCanvas
        anchors.fill:   parent

        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2
            const cy = height / 2
            const lw = width * 0.045
            const r = (width / 2) - lw
            const deg = Math.PI / 180

            // Canvas angles: 0 = right, clockwise. "Up" on the left side is 180 + a, on the right side 360 - a.
            function arc(from, to, color) {
                ctx.strokeStyle = color
                ctx.lineWidth = lw
                ctx.beginPath()
                ctx.arc(cx, cy, r, from * deg, to * deg)
                ctx.stroke()
            }
            arc(180, 180 + _maxScale, gauge._yellow)          // left, upper
            arc(180 - _maxScale, 180, gauge._blue)            // left, lower
            arc(360 - _maxScale, 360, gauge._yellow)          // right, upper
            arc(0, _maxScale, gauge._blue)                    // right, lower

            // Ticks
            ctx.strokeStyle = "#12161B"
            ctx.lineWidth = Math.max(1, width * 0.012)
            for (let a = -_maxScale; a <= _maxScale; a += 10) {
                for (const side of [ 180 + a, 360 - a ]) {
                    const x1 = cx + (r - lw / 2) * Math.cos(side * deg)
                    const y1 = cy + (r - lw / 2) * Math.sin(side * deg)
                    const x2 = cx + (r + lw / 2) * Math.cos(side * deg)
                    const y2 = cy + (r + lw / 2) * Math.sin(side * deg)
                    ctx.beginPath()
                    ctx.moveTo(x1, y1)
                    ctx.lineTo(x2, y2)
                    ctx.stroke()
                }
            }

            // Labels 40 / 20 / 0 / 20 / 40 inside the ring on the left
            ctx.fillStyle = gauge._blue
            ctx.font = "bold " + Math.round(width * 0.075) + "px sans-serif"
            ctx.textAlign = "left"
            ctx.textBaseline = "middle"
            const lr = r - lw * 1.6
            for (let a = -_maxScale; a <= _maxScale; a += 20) {
                const side = 180 + a
                ctx.fillStyle = a > 0 ? gauge._yellow : gauge._blue
                ctx.fillText(Math.abs(a).toString(), cx + lr * Math.cos(side * deg), cy + lr * Math.sin(side * deg))
            }
        }
    }

    // Rotating boat silhouette with its waterline
    Item {
        anchors.fill:       parent
        rotation:           gauge.isPitch ? -gauge._shownAngle : gauge._shownAngle
        transformOrigin:    Item.Center

        Behavior on rotation { NumberAnimation { duration: 100 } }

        Rectangle {
            anchors.centerIn:   parent
            width:              parent.width * 0.78
            height:             Math.max(2, parent.width * 0.018)
            color:              gauge._blue
        }

        Image {
            anchors.horizontalCenter:   parent.horizontalCenter
            anchors.bottom:             parent.verticalCenter
            anchors.bottomMargin:       -height * 0.18      // hull sits in the water a little
            width:                      parent.width * (gauge.isPitch ? 0.56 : 0.46)
            height:                     width * 0.6
            source:                     gauge.isPitch ? "/qmlimages/GidroLogBoatSide.svg" : "/qmlimages/GidroLogBoatRear.svg"
            sourceSize.width:           width * 2
            fillMode:                   Image.PreserveAspectFit
            mipmap:                     true
        }
    }

    // Caption and value
    Column {
        anchors.horizontalCenter:   parent.horizontalCenter
        y:                          parent.height * 0.6
        spacing:                    0

        QGCLabel {
            anchors.horizontalCenter:   parent.horizontalCenter
            text:                       gauge.caption
            color:                      gauge._blue
            font.bold:                  true
            font.pointSize:             ScreenTools.smallFontPointSize
        }

        QGCLabel {
            anchors.horizontalCenter:   parent.horizontalCenter
            text:                       isNaN(gauge.angle) ? "--" : gauge.angle.toFixed(1) + "°"
            color:                      "white"
            font.bold:                  true
            font.pointSize:             ScreenTools.mediumFontPointSize
        }
    }
}
