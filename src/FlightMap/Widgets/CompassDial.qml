import QtQuick

import QGroundControl
import QGroundControl.Controls

/// GidroLog: compass dial in the same style as the pitch/roll inclinometers:
/// dark face, coloured ring with ticks every 11.25 deg (major every 45 deg),
/// cardinal and intercardinal points labelled in degrees with the inclinometer font.
Item {
    id: control

    property real heading:      0
    property bool lockNoseUp:   false

    readonly property color _yellow:    "#FFD54F"
    readonly property color _blue:      "#29B6F6"

    onWidthChanged:     dialCanvas.requestPaint()
    onHeightChanged:    dialCanvas.requestPaint()
    onHeadingChanged:   if (lockNoseUp) dialCanvas.requestPaint()
    onLockNoseUpChanged: dialCanvas.requestPaint()

    Canvas {
        id:             dialCanvas
        anchors.fill:   parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2
            const cy = height / 2
            const lw = width * 0.045
            const r = (width / 2) - lw
            const deg = Math.PI / 180

            // Ring (canvas angle 0 = east, compass 0 = north)
            ctx.strokeStyle = control._blue
            ctx.lineWidth = lw
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.stroke()

            // North sector of the ring highlighted
            ctx.strokeStyle = control._yellow
            ctx.beginPath()
            ctx.arc(cx, cy, r, (-90 - 11.25) * deg, (-90 + 11.25) * deg)
            ctx.stroke()

            // Ticks every 11.25 deg, major ones (every 45 deg) cross the whole ring and go inside
            ctx.strokeStyle = "#12161B"
            for (let i = 0; i < 32; i++) {
                const a = (i * 11.25 - 90) * deg
                const major = (i % 4) === 0
                ctx.lineWidth = Math.max(1, width * (major ? 0.016 : 0.012))
                const r1 = r - lw / 2
                const r2 = r + lw / 2
                ctx.beginPath()
                ctx.moveTo(cx + r1 * Math.cos(a), cy + r1 * Math.sin(a))
                ctx.lineTo(cx + r2 * Math.cos(a), cy + r2 * Math.sin(a))
                ctx.stroke()
            }

            // Degree labels at the cardinal and intercardinal points
            ctx.font = "bold " + Math.round(width * 0.075) + "px sans-serif"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            const lr = r - lw * 1.9
            for (let i = 0; i < 8; i++) {
                const compassDeg = i * 45
                const a = (compassDeg - 90) * deg
                const x = cx + lr * Math.cos(a)
                const y = cy + lr * Math.sin(a)
                ctx.save()
                ctx.translate(x, y)
                if (control.lockNoseUp) {
                    ctx.rotate(control.heading * deg)    // keep labels upright when the dial turns
                }
                ctx.fillStyle = compassDeg === 0 ? control._yellow : control._blue
                ctx.fillText(compassDeg.toString(), 0, 0)
                ctx.restore()
            }
        }
    }
}
