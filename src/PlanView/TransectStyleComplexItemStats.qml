import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Statistics section for TransectStyleComplexItems
Grid {
    // The following properties must be available up the hierarchy chain
    //property var    missionItem       ///< Mission Item for editor

    columns:        2
    columnSpacing:  ScreenTools.defaultFontPixelWidth

    QGCLabel { text: qsTr("Площадь съёмки") }
    QGCLabel { text: QGroundControl.unitsConversion.squareMetersToAppSettingsAreaUnits(missionItem.coveredArea).toFixed(2) + " " + QGroundControl.unitsConversion.appSettingsAreaUnitsString }

    QGCLabel { text: qsTr("Кадров") }
    QGCLabel { text: missionItem.cameraShots }

    QGCLabel { text: qsTr("Интервал съёмки") }
    QGCLabel { text: missionItem.timeBetweenShots.toFixed(1) + " " + qsTr("с") }

    QGCLabel { text: qsTr("Шаг съёмки") }
    QGCLabel { text: missionItem.cameraCalc.adjustedFootprintFrontal.valueString + " " + missionItem.cameraCalc.adjustedFootprintFrontal.units }
}
