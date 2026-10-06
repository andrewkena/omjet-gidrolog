import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight
    width: parent.width  // grows when Loader is wider than implicitWidth

    FactPanelController { id: controller; }

    property Fact _copterFenceAction: controller.getParameterFact(-1, "FENCE_ACTION", false /* reportMissing */)
    property Fact _copterFenceEnable: controller.getParameterFact(-1, "FENCE_ENABLE", false /* reportMissing */)
    property Fact _copterFenceType:   controller.getParameterFact(-1, "FENCE_TYPE", false /* reportMissing */)

    ColumnLayout {
        id: mainLayout
        spacing: 0

        VehicleSummaryRow {
            labelText: qsTr("Предстартовые проверки:")
            valueText: {
                if (_armingCheckFact) {
                    return _armingCheckFact.value & 1 ? qsTr("Включено") : qsTr("Частично отключены")
                } else if (_armingSkipCheckFact) {
                    return _armingSkipCheckFact.value === 0 ? qsTr("Включено") : qsTr("Частично отключены")
                }
                return ""
            }

            // Older firmwares use ARMING_CHECK. Newer firmwares use ARMING_SKIPCHK.
            property Fact _armingCheckFact:     controller.getParameterFact(-1, "ARMING_CHECK", false /* reportMissing */)
            property Fact _armingSkipCheckFact: controller.getParameterFact(-1, "ARMING_SKIPCHK", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText: qsTr("Геозона:")
            valueText: {
                if(_copterFenceEnable && _copterFenceType) {
                    if(_copterFenceEnable.value == 0 || _copterFenceType.value == 0) {
                        return qsTr("Отключено")
                    } else {
                        if(_copterFenceType.value == 1) {
                            return qsTr("Высота")
                        }
                        if(_copterFenceType.value == 2) {
                            return qsTr("Круг")
                        }
                        return qsTr("Высота, круг")
                    }
                }
                return ""
            }
            visible: controller.vehicle.multiRotor
        }

        VehicleSummaryRow {
            labelText: qsTr("Геозона:")
            valueText: _copterFenceAction ? (_copterFenceAction.value == 0 ?
                           qsTr("Только сообщать") :
                           (_copterFenceAction.value == 1 ? qsTr("Возврат или посадка") : qsTr("Неизвестно"))) : ""
            visible: controller.vehicle.multiRotor && _copterFenceEnable && _copterFenceEnable.value !== 0
        }

        VehicleSummaryRow {
            labelText:  qsTr("Мин. высота возврата:")
            valueText:  fact ? (fact.value == 0 ? qsTr("текущая") : fact.valueString + " " + fact.units) : ""
            visible:    controller.vehicle.multiRotor

            property Fact fact: controller.getParameterFact(-1, "RTL_ALT_M", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("Мин. высота возврата:")
            valueText:  fact ? (fact.value < 0 ? qsTr("текущая") : fact.valueString + " " + fact.units) : ""
            visible:    controller.vehicle.fixedWing

            property Fact fact: controller.getParameterFact(-1, "RTL_ALTITUDE", false /* reportMissing */)
        }
    }
}
