import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Editor for Simple mission items
Rectangle {
    required property var missionItem
    required property real availableWidth

    id: root
    width: availableWidth
    height: editorColumn.height + (_margin * 2)
    color: qgcPal.windowShadeDark
    radius: _radius


    property bool _specifiesAltitude: missionItem.specifiesAltitude
    property real _margin: ScreenTools.defaultFontPixelHeight / 2
    property real _altRectMargin: ScreenTools.defaultFontPixelWidth / 2
    property var _controllerVehicle: missionItem.masterController.controllerVehicle
    property int _globalAltFrame: missionItem.masterController.missionController.globalAltitudeFrame
    property bool _globalAltFrameIsMixed: _globalAltFrame == QGroundControl.AltitudeFrameMixed
    property real _radius: ScreenTools.defaultFontPixelWidth / 2
    property real _fieldSpacing: ScreenTools.defaultFontPixelHeight / 2

    // GidroLog: Russian names of mission command parameters
    readonly property var _paramRu: ({
        "Hold":             qsTr("Ожидание"),
        "Hold time":        qsTr("Время ожидания"),
        "Acceptance":       qsTr("Радиус достижения"),
        "Accept Radius":    qsTr("Радиус достижения"),
        "Acceptance radius": qsTr("Радиус достижения"),
        "Pass Radius":      qsTr("Радиус прохода"),
        "Pass radius":      qsTr("Радиус прохода"),
        "Yaw":              qsTr("Курс"),
        "Heading":          qsTr("Курс"),
        "Radius":           qsTr("Радиус"),
        "Turns":            qsTr("Витки"),
        "Time":             qsTr("Время"),
        "Delay":            qsTr("Задержка"),
        "Speed":            qsTr("Скорость"),
        "Speed type":       qsTr("Тип скорости"),
        "Speed Type":       qsTr("Тип скорости"),
        "Throttle":         qsTr("Газ"),
        "Distance":         qsTr("Расстояние"),
        "Mode":             qsTr("Режим"),
        "Relative":         qsTr("Относительно"),
        "Direction":        qsTr("Направление"),
        "Angle":            qsTr("Угол"),
        "Channel":          qsTr("Канал"),
        "Servo":            qsTr("Серво"),
        "PWM":              qsTr("ШИМ"),
        "Relay":            qsTr("Реле"),
        "Count":            qsTr("Количество"),
        "Cycle time":       qsTr("Период"),
        "Setting":          qsTr("Значение"),
        "Item #":           qsTr("Точка №"),
        "Repeat":           qsTr("Повторов"),
        "Latitude":         qsTr("Широта"),
        "Longitude":        qsTr("Долгота"),
        "Altitude":         qsTr("Высота")
    })

    function _ruName(name) {
        return _paramRu[name] !== undefined ? _paramRu[name] : name
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }

    Column {
        id: editorColumn
        anchors.margins: _margin
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: _margin

        // Takeoff item
        ColumnLayout {
            anchors.margins: _margin
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: _margin
            visible: missionItem.isTakeoffItem && missionItem.wizardMode // Hack special case for takeoff item

            QGCLabel {
                text: qsTr("Перенесите «%1» %2 в %3 точку. %4")
                    .arg(_controllerVehicle.vtol ? qsTr("T") : qsTr("T"))
                    .arg(_controllerVehicle.vtol ? qsTr("направление перехода") : qsTr("взлёта"))
                    .arg(_controllerVehicle.vtol ? qsTr("нужную") : qsTr("начальную"))
                    .arg(_controllerVehicle.vtol ? (qsTr("Расстояние от старта до направления перехода должно быть достаточным для перехода.")) : "")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: !initialClickLabel.visible
            }

            QGCLabel {
                text: qsTr("Убедитесь, что нет препятствий, и направьте против ветра.")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: !initialClickLabel.visible
            }

            QGCButton {
                text: qsTr("Готово")
                Layout.fillWidth: true
                visible: !initialClickLabel.visible
                onClicked: {
                    missionItem.wizardMode = false
                }
            }

            QGCLabel {
                id: initialClickLabel
                text: missionItem.launchTakeoffAtSameLocation ?
                                        qsTr("Нажмите на карту, чтобы задать точку взлёта.") :
                                        qsTr("Нажмите на карту, чтобы задать точку старта.")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: missionItem.isTakeoffItem && !missionItem.launchCoordinate.isValid
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: _fieldSpacing
            visible: !missionItem.wizardMode

            QGCTabBar {
                id: tabBar
                Layout.fillWidth: true
                visible: false      // GidroLog: no tabs - only the parameters page (basic page only if there is nothing else)

                property bool showBasicItems:    !_advancedItemsAvailable && _basicItemsAvailable
                property bool showCameraItems:   false
                property bool showAdvancedItems: _advancedItemsAvailable

                property bool _basicItemsAvailable: _specifiesAltitude || missionItem.speedSection.available || missionItem.comboboxFacts.count > 0 || missionItem.textFieldFacts.count > 0 || missionItem.nanFacts.count > 0
                property bool _advancedItemsAvailable: missionItem.comboboxFactsAdvanced.count > 0 || missionItem.textFieldFactsAdvanced.count > 0 || missionItem.nanFactsAdvanced.count > 0
                property bool _cameraAvailable: missionItem.cameraSection.available

                function _multipleTabsVisible() {
                    let visibleCount = 0
                    if (_basicItemsAvailable) visibleCount++
                    if (_cameraAvailable) visibleCount++
                    if (_advancedItemsAvailable) visibleCount++
                    return visibleCount > 1
                }

                Component.onCompleted: {
                    if (_basicItemsAvailable) {
                        tabBar.currentIndex = 0
                    } else if (_cameraAvailable) {
                        tabBar.currentIndex = 1
                    } else if (_advancedItemsAvailable) {
                        tabBar.currentIndex = 2
                    } else {
                        tabBar.currentIndex = -1
                    }
                }

                QGCTabButton {
                    id: basicItemsTab
                    icon.source: "/res/PlanSimpleItemBasic.svg"
                    visible: tabBar._basicItemsAvailable
                }

                QGCTabButton {
                    id: cameraTab
                    icon.source: "/res/PlanSimpleItemCamera.svg"
                    visible: tabBar._cameraAvailable
                }

                QGCTabButton {
                    id: advancedItemsTab
                    icon.source: "/res/PlanSimpleItemAdvanced.svg"
                    visible: tabBar._advancedItemsAvailable
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: _fieldSpacing
                visible: tabBar.showBasicItems

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: _fieldSpacing
                    visible: false      // GidroLog: altitude not used on the boat (was _specifiesAltitude)

                    RowLayout {
                        Layout.fillWidth: true
                        visible: _globalAltFrameIsMixed

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Опорная высота")
                        }

                        AltFrameCombo {
                            altitudeFrame: missionItem.altitudeFrame
                            vehicle: _controllerVehicle
                            onAltitudeFrameChanged: missionItem.altitudeFrame = altitudeFrame
                        }
                    }

                    FactTextFieldSlider {
                        id: altField
                        Layout.fillWidth: true
                        label: qsTr("Высота%1").arg(_extraLabelText())
                        fact: missionItem.altitude

                        function _extraLabelText() {
                            return qsTr(" (%1)").arg(QGroundControl.altitudeFrameExtraUnits(missionItem.altitudeFrame))
                        }
                    }

                    QGCLabel {
                        font.pointSize: ScreenTools.smallFontPointSize
                        text: qsTr("Отправляемая высота над уровнем моря: %1 %2").arg(missionItem.amslAltAboveTerrain.valueString).arg(missionItem.amslAltAboveTerrain.units)
                        visible: missionItem.altitudeFrame === QGroundControl.AltitudeFrameCalcAboveTerrain
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: _fieldSpacing

                    Repeater {
                        model: missionItem.comboboxFacts

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QGCLabel {
                                font.pointSize: ScreenTools.smallFontPointSize
                                text: root._ruName(object.name)
                                visible: object.name !== ""
                            }

                            FactComboBox {
                                Layout.fillWidth: true
                                indexModel: false
                                model: object.enumStrings
                                fact: object
                            }
                        }
                    }
                }

                Repeater {
                    model: missionItem.textFieldFacts

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: root._ruName(object.name)
                        fact: object
                        enabled: !object.readOnly
                        warnOnUserMinMaxInvalid: false
                    }
                }

                Repeater {
                    model: missionItem.nanFacts

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: root._ruName(object.name)
                        fact: object
                        showEnableCheckbox: true
                        enableCheckBoxChecked: !isNaN(object.rawValue)
                        warnOnUserMinMaxInvalid: false

                        onEnableCheckboxClicked: object.rawValue = enableCheckBoxChecked ? 0 : NaN
                    }
                }

                FactTextFieldSlider {
                    Layout.fillWidth: true
                    label: qsTr("Скорость хода")
                    fact: missionItem.speedSection.flightSpeed
                    showEnableCheckbox: true
                    enableCheckBoxChecked: missionItem.speedSection.specifyFlightSpeed
                    visible: missionItem.speedSection.available

                    onEnableCheckboxClicked: missionItem.speedSection.specifyFlightSpeed = enableCheckBoxChecked
                }
            }

            CameraSection {
                Layout.fillWidth: true
                showSectionHeader: false
                missionItem: root.missionItem
                visible: tabBar.showCameraItems

                Component.onCompleted: checked = missionItem.cameraSection.settingsSpecified
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: _fieldSpacing
                visible: tabBar.showAdvancedItems

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: _fieldSpacing

                    Repeater {
                        model: missionItem.comboboxFactsAdvanced

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QGCLabel {
                                font.pointSize: ScreenTools.smallFontPointSize
                                text: root._ruName(object.name)
                                visible: object.name !== ""
                            }

                            FactComboBox {
                                Layout.fillWidth: true
                                indexModel: false
                                model: object.enumStrings
                                fact: object
                            }
                        }
                    }
                }

                Repeater {
                    model: missionItem.textFieldFactsAdvanced

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: root._ruName(object.name)
                        fact: object
                        enabled: !object.readOnly
                        warnOnUserMinMaxInvalid: false
                    }
                }

                Repeater {
                    model: missionItem.nanFactsAdvanced

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: root._ruName(object.name)
                        fact: object
                        showEnableCheckbox: true
                        enableCheckBoxChecked: !isNaN(object.rawValue)
                        warnOnUserMinMaxInvalid: false

                        onEnableCheckboxClicked: object.rawValue = enableCheckBoxChecked ? 0 : NaN
                    }
                }
            }
        }
    }
}
