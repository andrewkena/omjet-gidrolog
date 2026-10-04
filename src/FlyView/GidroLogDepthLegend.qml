import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// GidroLog: depth color legend (editable min/max) + slider for the depth label interval.
// Settings object lives in FlyViewMap (depthColorSettings) so the track reacts to changes immediately.
Item {
    id:             control
    implicitWidth:  mainLayout.implicitWidth + (_margin * 2)
    implicitHeight: mainLayout.implicitHeight + (_margin * 2)

    property var  settings                  // FlyViewMap.depthColorSettings
    property real _margin: ScreenTools.defaultFontPixelWidth * 0.75

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Rectangle {
        anchors.fill:   parent
        color:          qgcPal.window
        radius:         ScreenTools.defaultFontPixelWidth / 2
        opacity:        0.75
    }

    RowLayout {
        id:                 mainLayout
        anchors.centerIn:   parent
        spacing:            ScreenTools.defaultFontPixelWidth * 1.5

        // Depth color scale
        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight * 0.25

            QGCLabel {
                text:           qsTr("Глубина, м")
                font.pointSize: ScreenTools.smallFontPointSize
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                QGCTextField {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 6
                    text:                   control.settings ? control.settings.depthMin : ""
                    numericValuesOnly:      true
                    onEditingFinished: {
                        const v = parseFloat(text.replace(",", "."))
                        if (!isNaN(v) && v >= 0 && v < control.settings.depthMax) {
                            control.settings.depthMin = v
                        }
                        text = control.settings.depthMin
                    }
                }

                Rectangle {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 14
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.8
                    border.color:           "black"
                    border.width:           1

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.00; color: "#ff0000" }
                        GradientStop { position: 0.25; color: "#ffff00" }
                        GradientStop { position: 0.50; color: "#00ff00" }
                        GradientStop { position: 0.75; color: "#00ffff" }
                        GradientStop { position: 1.00; color: "#0000ff" }
                    }
                }

                QGCTextField {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 6
                    text:                   control.settings ? control.settings.depthMax : ""
                    numericValuesOnly:      true
                    onEditingFinished: {
                        const v = parseFloat(text.replace(",", "."))
                        if (!isNaN(v) && v > control.settings.depthMin) {
                            control.settings.depthMax = v
                        }
                        text = control.settings.depthMax
                    }
                }
            }
        }

        // Vertical separator
        Rectangle {
            Layout.fillHeight:      true
            Layout.preferredWidth:  1
            color:                  qgcPal.text
            opacity:                0.35
        }

        // Depth label interval
        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight * 0.25

            QGCLabel {
                text:           intervalSlider.value > 60 ? qsTr("Подписи глубины: выкл") : qsTr("Подписи глубины: каждые %1 с").arg(intervalSlider.value)
                font.pointSize: ScreenTools.smallFontPointSize
            }

            QGCSlider {
                id:                     intervalSlider
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 18
                from:                   2
                to:                     61      // far right (61) = labels off
                stepSize:               1
                snapMode:               Slider.SnapAlways
                value:                  control.settings ? control.settings.markerIntervalSec : 10
                onMoved:                control.settings.markerIntervalSec = value
            }
        }

        // Vertical separator
        Rectangle {
            Layout.fillHeight:      true
            Layout.preferredWidth:  1
            color:                  qgcPal.text
            opacity:                0.35
        }

        // Live depth map overlay on/off
        QGCButton {
            Layout.alignment:   Qt.AlignVCenter
            text:               qsTr("Карта глубин")
            checkable:          true
            checked:            control.settings ? control.settings.showDepthMap : true
            onClicked:          control.settings.showDepthMap = checked
        }
    }
}
