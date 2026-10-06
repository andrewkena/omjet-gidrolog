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

    FactPanelController { id: controller }

    function getFact(name) {
        return controller.getParameterFact(-1, name, false)
    }

    property bool followParamsAvailable: controller.parameterExists(-1, "FOLL_SYSID")

    property var followItems: [
        { label: qsTr("Следование"),    fact: getFact("FOLL_ENABLE"),       visible: true},
        { label: qsTr("ID системы для следования"),  fact: getFact("FOLL_SYSID"),        visible: followParamsAvailable },
        { label: qsTr("Макс. расстояние"),      fact: getFact("FOLL_DIST_MAX"),     visible: followParamsAvailable },
        { label: qsTr("Смещение X"),          fact: getFact("FOLL_OFS_X"),        visible: followParamsAvailable },
        { label: qsTr("Смещение Y"),          fact: getFact("FOLL_OFS_Y"),        visible: followParamsAvailable },
        { label: qsTr("Смещение Z"),          fact: getFact("FOLL_OFS_Z"),        visible: followParamsAvailable },
        { label: qsTr("Тип смещения"),       fact: getFact("FOLL_OFS_TYPE"),     visible: followParamsAvailable },
        { label: qsTr("Тип высоты"),     fact: getFact("FOLL_ALT_TYPE"),     visible: followParamsAvailable },
        { label: qsTr("Поведение по курсу"),      fact: getFact("FOLL_YAW_BEHAVE"),   visible: followParamsAvailable }
    ]

    ColumnLayout {
        id: mainLayout
        spacing: 0

        Repeater {
            model: followItems
            delegate: VehicleSummaryRow {
                labelText: modelData.label
                valueText: formatFact(modelData.fact)
                visible: modelData.visible

                function formatFact(fact) {
                    return (fact && (fact.enumStringValue || (fact.valueString + " " + fact.units)))
                }
            }
        }
    }
}
