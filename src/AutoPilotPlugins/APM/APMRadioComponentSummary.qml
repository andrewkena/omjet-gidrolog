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

    property Fact mapRollFact:      controller.getParameterFact(-1, "RCMAP_ROLL")
    property Fact mapPitchFact:     controller.getParameterFact(-1, "RCMAP_PITCH")
    property Fact mapYawFact:       controller.getParameterFact(-1, "RCMAP_YAW")
    property Fact mapThrottleFact:  controller.getParameterFact(-1, "RCMAP_THROTTLE")

    ColumnLayout {
        id: mainLayout
        width: parent.width
        spacing: 0

        VehicleSummaryRow {
            labelText: qsTr("Крен")
            valueText: mapRollFact.value == 0 ? qsTr("Требуется настройка") : qsTr("Канал %1").arg(mapRollFact.valueString)
        }

        VehicleSummaryRow {
            labelText: qsTr("Тангаж")
            valueText: mapPitchFact.value == 0 ? qsTr("Требуется настройка") : qsTr("Канал %1").arg(mapPitchFact.valueString)
        }

        VehicleSummaryRow {
            labelText: qsTr("Рыскание")
            valueText: mapYawFact.value == 0 ? qsTr("Требуется настройка") : qsTr("Канал %1").arg(mapYawFact.valueString)
        }

        VehicleSummaryRow {
            labelText: qsTr("Газ")
            valueText: mapThrottleFact.value == 0 ? qsTr("Требуется настройка") : qsTr("Канал %1").arg(mapThrottleFact.valueString)
        }
    }
}
