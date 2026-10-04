import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id: _root

    required property var missionController

    width:  parent ? parent.width : 0
    height: mainColumn.height + (_margins * 2)
    color:  QGroundControl.globalPalette.windowShadeDark

    property real _margins:        ScreenTools.defaultFontPixelWidth / 2
    property real _textFieldWidth: ScreenTools.defaultFontPixelWidth * 20
    property real _labelWidth:     ScreenTools.defaultFontPixelWidth * 14
    property bool _hasHome:        missionController ? missionController.plannedHomePosition.isValid : false

    TransformPositionController {
        id: positionController
        Component.onCompleted: {
            if (_hasHome) {
                coordinate = _root.missionController.plannedHomePosition
                initValues()
            }
        }
    }

    Connections {
        target: _root.missionController
        function onPlannedHomePositionChanged() {
            positionController.coordinate = _root.missionController.plannedHomePosition
            positionController.initValues()
        }
    }

    ColumnLayout {
        id:              mainColumn
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.top:     parent.top
        anchors.margins: _margins
        spacing:         ScreenTools.defaultFontPixelHeight * 0.5

        // ── Offset Mission ──
        SectionHeader {
            id:               offsetSection
            Layout.fillWidth: true
            text:             qsTr("Сместить задание")
            checked:          false
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing:          _margins
            visible:          offsetSection.checked

            LabelledFactTextField {
                id:                      eastField
                label:                   qsTr("Восток")
                fact:                    positionController.offsetEast
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
            }

            LabelledFactTextField {
                id:                      northField
                label:                   qsTr("Север")
                fact:                    positionController.offsetNorth
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
            }

            LabelledFactTextField {
                id:                      upField
                label:                   qsTr("Вверх")
                fact:                    positionController.offsetUp
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
            }

            QGCCheckBox {
                id:   offsetTakeoffCheck
                text: qsTr("Также сместить точки взлёта")
            }

            QGCCheckBox {
                id:   offsetLandingCheck
                text: qsTr("Также сместить точки посадки")
            }

            QGCLabel {
                Layout.fillWidth:    true
                Layout.maximumWidth: _labelWidth + _textFieldWidth
                wrapMode:            Text.WordWrap
                font.pointSize:      ScreenTools.smallFontPointSize
                text:                qsTr("Высота точки старта не меняется.")
            }

            QGCButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Применить смещение")
                enabled:          !eastField.textField.validationError
                                  && !northField.textField.validationError
                                  && !upField.textField.validationError

                onClicked: {
                    _root.missionController.offsetMission(
                        positionController.offsetEast.rawValue,
                        positionController.offsetNorth.rawValue,
                        positionController.offsetUp.rawValue,
                        offsetTakeoffCheck.checked,
                        offsetLandingCheck.checked
                    )
                }
            }
        }

        // ── Reposition Mission ──
        SectionHeader {
            id:               repositionSection
            Layout.fillWidth: true
            text:             qsTr("Перенести задание")
            checked:          false
        }

        ColumnLayout {
            id:               repositionContent
            Layout.fillWidth: true
            spacing:          _margins
            visible:          repositionSection.checked

            QGCLabel {
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                font.pointSize:   ScreenTools.smallFontPointSize
                text:             qsTr("Чтобы перенести задание, задайте точку старта.")
                visible:          !_hasHome
            }

            property bool _showGeographic: coordinateSystemCombo.currentIndex === 0
            property bool _showUTM:        coordinateSystemCombo.currentIndex === 1
            property bool _showMGRS:       coordinateSystemCombo.currentIndex === 2
            property bool _showVehicle:    coordinateSystemCombo.currentIndex === 3

            ColumnLayout {
                Layout.fillWidth: true
                spacing:          0

                QGCLabel {
                    text: qsTr("Система координат")
                }

                QGCComboBox {
                    id:               coordinateSystemCombo
                    Layout.fillWidth: true
                    model:            globals.activeVehicle
                                      ? [ qsTr("Географическая"), qsTr("UTM"), qsTr("MGRS"), qsTr("Положение борта") ]
                                      : [ qsTr("Географическая"), qsTr("UTM"), qsTr("MGRS") ]
                }
            }

            LabelledFactTextField {
                id:                      latitudeField
                label:                   qsTr("Широта")
                fact:                    positionController.latitude
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showGeographic
            }

            LabelledFactTextField {
                id:                      longitudeField
                label:                   qsTr("Долгота")
                fact:                    positionController.longitude
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showGeographic
            }

            QGCButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Перенести в точку")
                enabled:          _hasHome && !latitudeField.textField.validationError && !longitudeField.textField.validationError
                visible:          repositionContent._showGeographic
                onClicked: {
                    positionController.setFromGeo()
                    _root.missionController.repositionMission(positionController.coordinate)
                }
            }

            LabelledFactTextField {
                id:                      zoneField
                label:                   qsTr("Зона")
                fact:                    positionController.zone
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showUTM
            }

            LabelledFactComboBox {
                label:            qsTr("Полушарие")
                fact:             positionController.hemisphere
                indexModel:       false
                Layout.fillWidth: true
                visible:          repositionContent._showUTM
            }

            LabelledFactTextField {
                id:                      eastingField
                label:                   qsTr("Восточное смещение")
                fact:                    positionController.easting
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showUTM
            }

            LabelledFactTextField {
                id:                      northingField
                label:                   qsTr("Северное смещение")
                fact:                    positionController.northing
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showUTM
            }

            QGCButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Перенести в точку")
                enabled:          _hasHome && !zoneField.textField.validationError && !eastingField.textField.validationError && !northingField.textField.validationError
                visible:          repositionContent._showUTM
                onClicked: {
                    positionController.setFromUTM()
                    _root.missionController.repositionMission(positionController.coordinate)
                }
            }

            LabelledFactTextField {
                id:                      mgrsField
                label:                   qsTr("MGRS")
                fact:                    positionController.mgrs
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showMGRS
            }

            QGCButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Перенести в точку")
                enabled:          _hasHome && !mgrsField.textField.validationError
                visible:          repositionContent._showMGRS
                onClicked: {
                    positionController.setFromMGRS()
                    _root.missionController.repositionMission(positionController.coordinate)
                }
            }

            QGCButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Перенести к борту")
                enabled:          _hasHome
                visible:          repositionContent._showVehicle
                onClicked: {
                    positionController.setFromVehicle()
                    _root.missionController.repositionMission(positionController.coordinate)
                }
            }
        }

        // ── Rotate Mission ──
        SectionHeader {
            id:               rotateSection
            Layout.fillWidth: true
            text:             qsTr("Повернуть задание")
            checked:          false
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing:          _margins
            visible:          rotateSection.checked

            QGCLabel {
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                font.pointSize:   ScreenTools.smallFontPointSize
                text:             qsTr("Чтобы повернуть задание, задайте точку старта.")
                visible:          !_hasHome
            }

            LabelledFactTextField {
                id:                      degreesCWField
                label:                   qsTr("По часовой стрелке")
                fact:                    positionController.rotateDegreesCW
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
            }

            QGCCheckBox {
                id:   rotateTakeoffCheck
                text: qsTr("Также сместить точки взлёта")
            }

            QGCCheckBox {
                id:   rotateLandingCheck
                text: qsTr("Также сместить точки посадки")
            }

            QGCLabel {
                Layout.fillWidth:    true
                Layout.maximumWidth: _labelWidth + _textFieldWidth
                wrapMode:            Text.WordWrap
                font.pointSize:      ScreenTools.smallFontPointSize
                text:                qsTr("Полигоны поворачиваются переносом их опорной точки: форма и ориентация не меняются.")
            }

            QGCButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Применить поворот")
                enabled:          _hasHome && !degreesCWField.textField.validationError

                onClicked: {
                    _root.missionController.rotateMission(
                        positionController.rotateDegreesCW.rawValue,
                        rotateTakeoffCheck.checked,
                        rotateLandingCheck.checked
                    )
                }
            }
        }
    }
}
