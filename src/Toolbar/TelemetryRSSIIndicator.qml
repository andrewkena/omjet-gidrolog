import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

//-------------------------------------------------------------------------
//-- Telemetry RSSI
Item {
    id:             control
    objectName:     "toolbar_telemetryRSSIIndicator"
    anchors.top:    parent.top
    anchors.bottom: parent.bottom
    width:          telemRow.width  // GidroLog: icon + numbers

    property bool showIndicator: _hasTelemetry

    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property var  _radioStatus:     _activeVehicle.radioStatus
    property bool _hasTelemetry:    _radioStatus.lrssi.rawValue !== 0

    Row {
        id:             telemRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth / 2

        QGCColoredImage {
            id:                 telemIcon
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            width:              height
            sourceSize.height:  height
            source:             "/qmlimages/TelemRSSI.svg"
            fillMode:           Image.PreserveAspectFit
            color:              qgcPal.buttonText
        }

        // GidroLog: link quality numbers - local/remote RSSI and MAVLink packet loss
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing:                0

            QGCLabel {
                color:  qgcPal.text
                text:   _radioStatus.lrssi.rawValue + " / " + _radioStatus.rrssi.rawValue + " дБм"
            }

            QGCLabel {
                color:  _activeVehicle.mavlinkLossPercent > 5 ? qgcPal.colorOrange : qgcPal.text
                text:   qsTr("потери ") + _activeVehicle.mavlinkLossPercent.toFixed(1) + "%"
            }
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.showIndicatorDrawer(telemRSSIInfoPage, control)
    }

    Component {
        id: telemRSSIInfoPage

        ToolIndicatorPage {
            showExpand: false

            contentComponent: SettingsGroupLayout {
                heading: qsTr("Состояние телеметрии")

                LabelledLabel {
                    label:      qsTr("Сигнал на пульте:")
                    labelText:  _radioStatus.lrssi.rawValue + " " + qsTr("дБм")
                }

                LabelledLabel {
                    label:      qsTr("Сигнал на борту:")
                    labelText:  _radioStatus.rrssi.rawValue + " " + qsTr("дБм")
                }

                LabelledLabel {
                    label:      qsTr("Ошибки приёма:")
                    labelText:  _radioStatus.rxErrors.rawValue
                }

                LabelledLabel {
                    label:      qsTr("Исправлено ошибок:")
                    labelText:  _radioStatus.fixed.rawValue
                }

                LabelledLabel {
                    label:      qsTr("Буфер передачи, %:")
                    labelText:  _radioStatus.txBuffer.rawValue
                }

                LabelledLabel {
                    label:      qsTr("Шум на пульте:")
                    labelText:  _radioStatus.lNoise.rawValue
                }

                LabelledLabel {
                    label:      qsTr("Шум на борту:")
                    labelText:  _radioStatus.rNoise.rawValue
                }
            }
        }
    }
}
