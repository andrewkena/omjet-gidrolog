import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    id: root

    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight
    width: parent.width

    readonly property bool _arspdTypeAvailable: controller.parameterExists(-1, "ARSPD_TYPE")
    readonly property Fact _arspdType: _arspdTypeAvailable ? controller.getParameterFact(-1, "ARSPD_TYPE") : null
    readonly property bool _sensorEnabled: _arspdTypeAvailable && _arspdType.rawValue !== 0
    readonly property bool _arspdUseAvailable: controller.parameterExists(-1, "ARSPD_USE")
    readonly property Fact _arspdUse: _arspdUseAvailable ? controller.getParameterFact(-1, "ARSPD_USE") : null
    readonly property bool _arspd2TypeAvailable: controller.parameterExists(-1, "ARSPD2_TYPE")
    readonly property Fact _arspd2Type: _arspd2TypeAvailable ? controller.getParameterFact(-1, "ARSPD2_TYPE") : null
    readonly property bool _cruiseAvailable: controller.parameterExists(-1, "AIRSPEED_CRUISE")
    readonly property Fact _cruise: _cruiseAvailable ? controller.getParameterFact(-1, "AIRSPEED_CRUISE") : null

    FactPanelController { id: controller }

    ColumnLayout {
        id: mainLayout

        spacing: 0

        VehicleSummaryRow {
            labelText: qsTr("Тип датчика")
            valueText: _arspdTypeAvailable ? _arspdType.enumStringValue : qsTr("Н/Д")
        }

        VehicleSummaryRow {
            labelText: qsTr("Использовать воздушную скорость")
            valueText: _arspdUseAvailable ? _arspdUse.enumStringValue : qsTr("Н/Д")
            visible: _sensorEnabled
        }

        VehicleSummaryRow {
            labelText: qsTr("Тип датчика 2")
            valueText: _arspd2TypeAvailable ? _arspd2Type.enumStringValue : qsTr("Н/Д")
            visible: _arspd2TypeAvailable
        }

        VehicleSummaryRow {
            labelText: qsTr("Крейсерская скорость")
            valueText: _cruiseAvailable ? _cruise.valueString + " " + _cruise.units : qsTr("Н/Д")
            visible: _sensorEnabled && _cruiseAvailable
        }
    }
}
