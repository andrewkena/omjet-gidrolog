import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SetupPage {
    id: escPage
    pageComponent: escPageComponent

    FactPanelController {
        id: controller
    }

    Component {
        id: escPageComponent

        ColumnLayout {
            width: availableWidth
            spacing: _margins

            // ESC Configuration properties - supports both MOT_* (Copter/Rover/Sub) and Q_M_* (QuadPlane) prefixes
            property bool _isQuadPlane: !controller.parameterExists(-1, "MOT_PWM_TYPE") && controller.parameterExists(-1, "Q_M_PWM_TYPE")
            property string _escPrefix: _isQuadPlane ? "Q_M_" : "MOT_"

            property bool _motPwmTypeAvailable: controller.parameterExists(-1, _escPrefix + "PWM_TYPE")
            property bool _motPwmMinAvailable: controller.parameterExists(-1, _escPrefix + "PWM_MIN")
            property bool _motPwmMaxAvailable: controller.parameterExists(-1, _escPrefix + "PWM_MAX")
            property bool _motSpinArmAvailable: controller.parameterExists(-1, _escPrefix + "SPIN_ARM")
            property bool _motSpinMinAvailable: controller.parameterExists(-1, _escPrefix + "SPIN_MIN")
            property bool _motSpinMaxAvailable: controller.parameterExists(-1, _escPrefix + "SPIN_MAX")
            property bool _servoDshotEscAvailable: controller.parameterExists(-1, "SERVO_DSHOT_ESC")
            property bool _servoDshotRateAvailable: controller.parameterExists(-1, "SERVO_DSHOT_RATE")

            property Fact _motPwmType: controller.getParameterFact(-1, _escPrefix + "PWM_TYPE", false /* reportMissing */)
            property Fact _motPwmMin: controller.getParameterFact(-1, _escPrefix + "PWM_MIN", false /* reportMissing */)
            property Fact _motPwmMax: controller.getParameterFact(-1, _escPrefix + "PWM_MAX", false /* reportMissing */)
            property Fact _motSpinArm: controller.getParameterFact(-1, _escPrefix + "SPIN_ARM", false /* reportMissing */)
            property Fact _motSpinMin: controller.getParameterFact(-1, _escPrefix + "SPIN_MIN", false /* reportMissing */)
            property Fact _motSpinMax: controller.getParameterFact(-1, _escPrefix + "SPIN_MAX", false /* reportMissing */)
            property Fact _servoDshotEsc: controller.getParameterFact(-1, "SERVO_DSHOT_ESC", false /* reportMissing */)
            property Fact _servoDshotRate: controller.getParameterFact(-1, "SERVO_DSHOT_RATE", false /* reportMissing */)

            property bool _isDshot: _motPwmTypeAvailable && _motPwmType && _motPwmType.rawValue >= 4

            property string _escCalParam: _isQuadPlane ? "Q_ESC_CAL" : "ESC_CALIBRATION"
            property bool _escCalibrationAvailable: controller.parameterExists(-1, _escCalParam)
            property Fact _escCalibration: controller.getParameterFact(-1, _escCalParam, false /* reportMissing */)

            property string _restartRequired: qsTr("Требуется перезагрузка судна")
            property real _fieldWidth: ScreenTools.defaultFontPixelWidth * 15
            property real _comboWidth: ScreenTools.defaultFontPixelWidth * 30

            QGCPalette { id: qgcPal; colorGroupEnabled: true }

            QGCGroupBox {
                title: qsTr("Конфигурация")
                visible: _motPwmTypeAvailable

                ColumnLayout {
                    spacing: _margins

                    LabelledFactComboBox {
                        label: qsTr("Тип выхода")
                        fact: _motPwmType
                        indexModel: false
                        comboBoxPreferredWidth: _comboWidth
                    }

                    QGCLabel {
                        text: _restartRequired
                        font.pointSize: ScreenTools.smallFontPointSize
                    }

                    LabelledFactTextField {
                        label: qsTr("Мин. ШИМ выхода")
                        fact: _motPwmMin
                        textFieldPreferredWidth: _fieldWidth
                        visible: _motPwmMinAvailable
                    }

                    LabelledFactTextField {
                        label: qsTr("Макс. ШИМ выхода")
                        fact: _motPwmMax
                        textFieldPreferredWidth: _fieldWidth
                        visible: _motPwmMaxAvailable
                    }

                    LabelledFactTextField {
                        label: qsTr("Вращение при запуске")
                        fact: _motSpinArm
                        textFieldPreferredWidth: _fieldWidth
                        visible: _motSpinArmAvailable
                    }

                    LabelledFactTextField {
                        label: qsTr("Мин. вращение")
                        fact: _motSpinMin
                        textFieldPreferredWidth: _fieldWidth
                        visible: _motSpinMinAvailable
                    }

                    LabelledFactTextField {
                        label: qsTr("Макс. вращение")
                        fact: _motSpinMax
                        textFieldPreferredWidth: _fieldWidth
                        visible: _motSpinMaxAvailable
                    }

                    // DShot settings - visible when a DShot protocol is selected
                    LabelledFactComboBox {
                        label: qsTr("Тип ESC DShot")
                        fact: _servoDshotEsc
                        indexModel: false
                        comboBoxPreferredWidth: _comboWidth
                        visible: _isDshot && _servoDshotEscAvailable
                    }

                    LabelledFactComboBox {
                        label: qsTr("Частота DShot")
                        fact: _servoDshotRate
                        indexModel: false
                        comboBoxPreferredWidth: _comboWidth
                        visible: _isDshot && _servoDshotRateAvailable
                    }
                }
            }

            QGCGroupBox {
                title: qsTr("Калибровка")
                visible: _escCalibrationAvailable

                ColumnLayout {
                    spacing: _margins

                    QGCLabel {
                        text: qsTr("ВНИМАНИЕ: перед калибровкой снимите винты!")
                        color: qgcPal.warningText
                    }

                    RowLayout {
                        spacing: _margins

                        QGCButton {
                            text: qsTr("Калибровать")
                            enabled: _escCalibration && _escCalibration.rawValue === 0
                            onClicked: if(_escCalibration) _escCalibration.rawValue = 3
                        }

                        ColumnLayout {
                            enabled: _escCalibration && _escCalibration.rawValue === 3
                            QGCLabel { text: _escCalibration ? (_escCalibration.rawValue === 3 ? qsTr("Теперь выполните шаги:") : qsTr("Нажмите «Калибровать», затем:")) : "" }
                            QGCLabel { text: qsTr("- Отключите USB и батарею, чтобы автопилот выключился") }
                            QGCLabel { text: qsTr("- Подключите батарею") }
                            QGCLabel { text: qsTr("- Прозвучит сигнал запуска (если подключён зуммер)") }
                            QGCLabel { text: qsTr("- Если есть кнопка безопасности, удерживайте её, пока она не загорится красным") }
                            QGCLabel { text: qsTr("- Прозвучит мелодия, затем два сигнала") }
                            QGCLabel { text: qsTr("- Через несколько секунд — серия сигналов (по одному на каждую банку батареи)") }
                            QGCLabel { text: qsTr("- В конце — один длинный сигнал: пределы заданы, ESC откалиброван") }
                            QGCLabel { text: qsTr("- Отключите батарею и включите судно как обычно") }
                        }
                    }
                }
            }
        } // ColumnLayout
    } // Component - escPageComponent

} // SetupPage
