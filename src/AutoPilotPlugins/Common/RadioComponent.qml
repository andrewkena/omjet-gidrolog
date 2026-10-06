import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.VehicleSetup

SetupPage {
    id: radioPage
    pageComponent: pageComponent

    Component {
        id: pageComponent

        RemoteControlCalibration {
            id: remoteControlCalibration

            useDeadband: false

            controller: RadioComponentController {
                statusText: remoteControlCalibration.statusText
                cancelButton: remoteControlCalibration.cancelButton
                nextButton: remoteControlCalibration.nextButton
                joystickMode: false

                onThrottleReversedCalFailure: QGroundControl.showMessageDialog(radioPage, qsTr("Канал газа реверсирован"), qsTr("Калибровка не удалась: канал газа на пульте реверсирован. Исправьте это на пульте, чтобы завершить калибровку."))
            }

            Component.onCompleted: controller.start()

            additionalSetupComponent: ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                ColumnLayout {
                    id: switchSettings
                    Layout.fillWidth: true

                    Repeater {
                        model: QGroundControl.multiVehicleManager.activeVehicle.px4Firmware ?
                                    (QGroundControl.multiVehicleManager.activeVehicle.multiRotor ?
                                        [ "RC_MAP_AUX1", "RC_MAP_AUX2", "RC_MAP_PARAM1", "RC_MAP_PARAM2", "RC_MAP_PARAM3", "RC_MAP_PAY_SW"] :
                                        [ "RC_MAP_FLAPS", "RC_MAP_AUX1", "RC_MAP_AUX2", "RC_MAP_PARAM1", "RC_MAP_PARAM2", "RC_MAP_PARAM3", "RC_MAP_PAY_SW"]) :
                                    0

                        LabelledFactComboBox {
                            label: fact.shortDescription
                            fact: controller.getParameterFact(-1, modelData)
                            indexModel: false
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: qgcPal.text
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCButton {
                        id: bindButton
                        text: qsTr("Привязка Spektrum")
                        onClicked: spektrumBindDialogFactory.open()
                    }

                    QGCButton {
                        text: qsTr("Привязка CRSF")
                        onClicked: QGroundControl.showMessageDialog(radioPage, qsTr("Привязка CRSF"),
                                                                qsTr("Нажмите OK, чтобы перевести приёмник CRSF в режим привязки."),
                                                                Dialog.Ok | Dialog.Cancel,
                                                                function() { controller.crsfBindMode() })
                    }

                    QGCButton {
                        text: qsTr("Копировать триммеры")
                        onClicked: QGroundControl.showMessageDialog(radioPage, qsTr("Копировать триммеры"),
                                                                qsTr("Отцентрируйте стики, газ в минимум, затем нажмите OK для копирования триммеров. После этого обнулите триммеры на пульте."),
                                                                Dialog.Ok | Dialog.Cancel,
                                                                function() { controller.copyTrims() })
                    }
                }

                QGCPopupDialogFactory {
                    id: spektrumBindDialogFactory

                    dialogComponent: spektrumBindDialogComponent
                }

                Component {
                    id: spektrumBindDialogComponent

                    QGCPopupDialog {
                        title: qsTr("Привязка Spektrum")
                        buttons: Dialog.Ok | Dialog.Cancel

                        onAccepted: { controller.spektrumBindMode(radioGroup.checkedButton.bindMode) }

                        ButtonGroup { id: radioGroup }

                        ColumnLayout {
                            spacing: ScreenTools.defaultFontPixelHeight / 2

                            QGCLabel {
                                wrapMode: Text.WordWrap
                                text: qsTr("Нажмите OK, чтобы перевести приёмник Spektrum в режим привязки.")
                            }

                            QGCLabel {
                                wrapMode: Text.WordWrap
                                text: qsTr("Выберите тип приёмника:")
                            }

                            QGCRadioButton {
                                text: qsTr("Режим DSM2")
                                ButtonGroup.group: radioGroup
                                property int bindMode: RadioComponentController.DSM2
                            }

                            QGCRadioButton {
                                text: qsTr("DSMX (7 каналов и меньше)")
                                ButtonGroup.group: radioGroup
                                property int bindMode: RadioComponentController.DSMX7
                            }

                            QGCRadioButton {
                                checked: true
                                text: qsTr("DSMX (8 каналов и больше)")
                                ButtonGroup.group: radioGroup
                                property int bindMode: RadioComponentController.DSMX8
                            }
                        }
                    }
                }
            }
        }
    }
}
