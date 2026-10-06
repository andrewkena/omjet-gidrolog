import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

/*
    IMPORTANT NOTE: Any changes made here must also be made to SensorsComponentSummary.qml
*/

Item {
    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight
    width: parent.width  // grows when Loader is wider than implicitWidth

    APMSensorsComponentController { id: controller; }

    APMSensorParams {
        id:                     sensorParams
        factPanelController:    controller
    }

    ColumnLayout {
        id: mainLayout
        width: parent.width
        spacing: 0

        VehicleSummaryRow {
        labelText:  qsTr("Компасы:")
        valueText: ""
        }

        Repeater {
            model: sensorParams.rgCompassAvailable.length
            RowLayout {
                Layout.fillWidth: true
                width: parent.width

                QGCLabel {

                    text:  sensorParams.rgCompassAvailable[index] ?
                                (sensorParams.rgCompassCalibrated[index] ?
                                     getPriority(index) +
                                     (sensorParams.rgCompassExternalParamAvailable[index] ?
                                          (sensorParams.rgCompassExternal[index] ? ", External" : ", Internal" ) :
                                          "") :
                                     qsTr("Требуется настройка")) :
                                qsTr("Не установлен")

                    function getPriority (index) {
                        if (sensorParams.rgCompassId[index].value == sensorParams.rgCompassPrio[0].value) {
                            return "Primary"
                        }
                        if (sensorParams.rgCompassId[index].value == sensorParams.rgCompassPrio[1].value) {
                            return "Secondary"
                        }
                        if (sensorParams.rgCompassId[index].value == sensorParams.rgCompassPrio[2].value) {
                            return "Tertiary"
                        }
                        return "Unused"
                    }
                }

                APMSensorIdDecoder {
                    horizontalAlignment:    Text.AlignRight
                    Layout.alignment:       Qt.AlignRight

                    fact: sensorParams.rgCompassPrio[index]
                }
            }
        }

        VehicleSummaryRow {
            labelText: qsTr("Акселерометр(ы):")
            valueText: controller.accelSetupNeeded ? qsTr("Требуется настройка") : qsTr("Готово")
        }

        Repeater {
            model: sensorParams.rgInsId.length
            APMSensorIdDecoder {
                fact:          sensorParams.rgInsId[index]
                Layout.alignment: Qt.AlignRight
            }
        }

        VehicleSummaryRow {
            labelText: qsTr("Барометр(ы):")
            valueText: sensorParams.baroIdAvailable ? "" : qsTr("Не поддерживается (APM 4.1 и новее)")
        }

        Repeater {
            model: sensorParams.rgBaroId.length
            APMSensorIdDecoder {
                fact:          sensorParams.rgBaroId[index]
                Layout.alignment: Qt.AlignRight
            }
        }
    }
}
