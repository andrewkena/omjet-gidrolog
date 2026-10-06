import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlightMap

TransectStyleComplexItemEditor {
    transectAreaDefinitionComplete: _missionItem.corridorPolyline.isValid
    transectAreaDefinitionHelp:     qsTr("Нарисуйте линию, вдоль которой пройдёт коридор (кнопки над картой).")
    transectValuesHeaderName:       qsTr("Коридор")
    transectValuesComponent:        _transectValuesComponent
    presetsTransectValuesComponent: _transectValuesComponent

    property real   _margin:        ScreenTools.defaultFontPixelWidth / 2
    property var    _missionItem:   missionItem

    Component {
        id: _transectValuesComponent

        GridLayout {
            columnSpacing:  _margin
            rowSpacing:     _margin
            columns:        2

            QGCLabel { text: qsTr("Ширина") }
            FactTextField {
                fact:               _missionItem.corridorWidth
                Layout.fillWidth:   true
            }

            QGCLabel {
                text:       qsTr("Дистанция разворота")
                visible:    !forPresets
            }
            FactTextField {
                fact:               _missionItem.turnAroundDistance
                Layout.fillWidth:   true
                visible:            !forPresets
            }

            FactCheckBox {
                Layout.columnSpan:  2
                text:               qsTr("Съёмка на разворотах")
                fact:               _missionItem.cameraTriggerInTurnAround
                enabled:            _missionItem.hoverAndCaptureAllowed ? !_missionItem.hoverAndCapture.rawValue : true
                visible:            !forPresets
            }
        }
    }
}
