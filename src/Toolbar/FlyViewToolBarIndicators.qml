import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Toolbar

Item {
    objectName:    "flyViewToolBarIndicators"
    implicitWidth: mainLayout.width + _widthMargin

    property var  _activeVehicle:           QGroundControl.multiVehicleManager.activeVehicle

    QGCPalette { id: qgcPal }
    property real _toolIndicatorMargins:    ScreenTools.defaultFontPixelHeight * 0.66
    property real _widthMargin:             _toolIndicatorMargins * 2

    Row {
        id:                 mainLayout
        anchors.margins:    _toolIndicatorMargins
        anchors.left:       parent.left
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        spacing:            ScreenTools.defaultFontPixelWidth * 1.75

        Repeater {
            id:     appRepeater
            model:  QGroundControl.corePlugin.toolBarIndicators
            Loader {
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                source:             modelData
                visible:            item.showIndicator
            }
        }

        Repeater {
            id:     toolIndicatorsRepeater
            model:  _activeVehicle ? _activeVehicle.toolIndicators : []

            // GidroLog: vertical separator before every visible indicator except the first one
            Row {
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                spacing:        mainLayout.spacing
                visible:        indicatorLoader.item ? indicatorLoader.item.showIndicator : false

                property bool _firstVisible: {
                    for (let i = 0; i < index; i++) {
                        const other = toolIndicatorsRepeater.itemAt(i)
                        if (other && other.visible) {
                            return false
                        }
                    }
                    return true
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:                  1
                    height:                 parent.height * 0.8
                    color:                  qgcPal.text
                    opacity:                0.35
                    visible:                !parent._firstVisible
                }

                Loader {
                    id:                 indicatorLoader
                    anchors.top:        parent.top
                    anchors.bottom:     parent.bottom
                    source:             modelData
                }
            }
        }
    }
}
