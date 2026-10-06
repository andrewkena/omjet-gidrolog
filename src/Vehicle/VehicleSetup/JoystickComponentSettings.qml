import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.VehicleSetup
import QGroundControl.FactControls

ColumnLayout {
    spacing: _margins

    required property var joystick

    readonly property var _joystickSettings: joystick.settings
    readonly property real _margins: ScreenTools.defaultFontPixelHeight / 2
    readonly property bool _anyAdvancedSettingsEnabled:
        _joystickSettings.circleCorrection.rawValue ||
        _joystickSettings.useDeadband.rawValue ||
        _joystickSettings.enableManualControlPitchExtension.rawValue ||
        _joystickSettings.enableManualControlRollExtension.rawValue ||
        _joystickSettings.enableAdditionalAxis1.rawValue ||
        _joystickSettings.enableAdditionalAxis2.rawValue ||
        _joystickSettings.enableAdditionalAxis3.rawValue ||
        _joystickSettings.enableAdditionalAxis4.rawValue ||
        _joystickSettings.enableAdditionalAxis5.rawValue ||
        _joystickSettings.enableAdditionalAxis6.rawValue

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: _margins
        Layout.rightMargin: _margins
        spacing: _margins

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("Центр стика — нулевой газ")
            fact: _joystickSettings.throttleModeCenterZero
            visible: fact.userVisible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("Сглаживание подпружиненного газа")
            fact: _joystickSettings.throttleSmoothing
            visible: fact.userVisible && _joystickSettings.throttleModeCenterZero.rawValue
        }

        FactTextFieldSlider {
            Layout.fillWidth: true
            label: fact.shortDescription
            fact: _joystickSettings.exponentialPct
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("Обратная тяга")
            fact: _joystickSettings.negativeThrust
            visible: globals.activeVehicle.supports.negativeThrust && fact.userVisible
        }

        QGCCheckBoxSlider {
            id: advancedSettingsCheckbox
            Layout.fillWidth: true
            text: qsTr("Дополнительные настройки")
            Component.onCompleted: checked = _anyAdvancedSettingsEnabled
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Дополнительные настройки")
        visible: advancedSettingsCheckbox.checked

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("Круговая коррекция")
            fact: _joystickSettings.circleCorrection
            visible: fact.userVisible
        }

        FactTextFieldSlider {
            Layout.fillWidth: true
            label: fact.shortDescription
            fact: _joystickSettings.axisFrequencyHz
            visible: fact.userVisible
        }

        FactTextFieldSlider {
            Layout.fillWidth: true
            label: fact.shortDescription
            fact: _joystickSettings.buttonFrequencyHz
            visible: fact.userVisible
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            FactCheckBoxSlider {
                text: qsTr("Мёртвая зона")
                fact: _joystickSettings.useDeadband
                visible: fact.userVisible
            }

            QGCLabel{
                Layout.fillWidth: true
                Layout.maximumWidth: additionalAxesRcChannelsOverride.x + additionalAxesRcChannelsOverride.width
                font.pointSize: ScreenTools.smallFontPointSize
                wrapMode: Text.WordWrap
                text: qsTr("Мёртвую зону можно задать на первом шаге калибровки, слегка покачав каждую ось. ")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth / 2

            QGCLabel { text: qsTr("Расширения MANUAL_CONTROL") }

            ColumnLayout {
                Layout.leftMargin: ScreenTools.defaultFontPixelWidth
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth / 2

                FactCheckBoxSlider {
                    Layout.fillWidth: true
                    text: qsTr("Тангаж")
                    fact: _joystickSettings.enableManualControlPitchExtension
                    visible: fact.userVisible
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true
                    text: qsTr("Крен")
                    fact: _joystickSettings.enableManualControlRollExtension
                    visible: fact.userVisible
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth / 2

            QGCLabel { text: qsTr("Доп. оси") }

            ColumnLayout {
                Layout.leftMargin: ScreenTools.defaultFontPixelWidth
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth / 2

                ColumnLayout {
                    spacing: 0

                    QGCRadioButton {
                        id: additionalAxesManualControl
                        text: qsTr("Отправлять через MANUAL_CONTROL")
                        checked: _joystickSettings.additionalAxesFunction.rawValue == 0
                        onClicked: _joystickSettings.additionalAxesFunction.rawValue = 0
                    }

                    QGCRadioButton {
                        id: additionalAxesRcChannelsOverride
                        text: qsTr("Отправлять через RC_CHANNELS_OVERRIDE")
                        checked: _joystickSettings.additionalAxesFunction.rawValue == 1
                        onClicked: _joystickSettings.additionalAxesFunction.rawValue = 1
                    }
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true
                    text: additionalAxesManualControl.checked ? qsTr("Доп. 1") : qsTr("Канал 5")
                    fact: _joystickSettings.enableAdditionalAxis1
                    visible: fact.userVisible
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true
                    text: additionalAxesManualControl.checked ? qsTr("Доп. 2") : qsTr("Канал 6")
                    fact: _joystickSettings.enableAdditionalAxis2
                    visible: fact.userVisible
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true
                    text: additionalAxesManualControl.checked ? qsTr("Доп. 3") : qsTr("Канал 7")
                    fact: _joystickSettings.enableAdditionalAxis3
                    visible: fact.userVisible
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true
                    text: additionalAxesManualControl.checked ? qsTr("Доп. 4") : qsTr("Канал 8")
                    fact: _joystickSettings.enableAdditionalAxis4
                    visible: fact.userVisible
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true
                    text: additionalAxesManualControl.checked ? qsTr("Доп. 5") : qsTr("Канал 9")
                    fact: _joystickSettings.enableAdditionalAxis5
                    visible: fact.userVisible
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true
                    text: additionalAxesManualControl.checked ? qsTr("Доп. 6") : qsTr("Канал 10")
                    fact: _joystickSettings.enableAdditionalAxis6
                    visible: fact.userVisible
                }
            }
        }
    }
}
