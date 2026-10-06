import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.FactControls
import QGroundControl.Controls

QGCPopupDialog {
    id:         popupDialog
    title:      qsTr("Расчёт множителя напряжения")
    buttons:    Dialog.Close

    property int  batteryIndex: 0
    property var  _controller:       controller
    property var  _batteryFactGroup: controller.vehicle.getFactGroup("battery" + batteryIndex)

    APMBatteryParams {
        id:             batParams
        controller:     _controller
        batteryIndex:   popupDialog.batteryIndex
    }

    ColumnLayout {
        spacing: ScreenTools.defaultFontPixelHeight

        QGCLabel {
            Layout.preferredWidth:  gridLayout.width
            wrapMode:               Text.WordWrap
            text:                   qsTr("Измерьте напряжение батареи внешним вольтметром и введите значение ниже. Нажмите «Рассчитать», чтобы задать новый множитель напряжения.")
        }

        QGCLabel {
            Layout.preferredWidth:  gridLayout.width
            wrapMode:               Text.WordWrap
            visible:                !_batteryFactGroup || _batteryFactGroup.voltage.value === 0
            text:                   qsTr("Нет телеметрии напряжения. Подключитесь к судну с включённой батареей для автоматического расчёта.")
            color:                  qgcPal.warningText
        }

        GridLayout {
            id:         gridLayout
            columns:    2

            QGCLabel { text: qsTr("Измеренное напряжение:") }
            QGCTextField { id: measuredVoltage; numericValuesOnly: true }

            QGCLabel {
                text:    qsTr("Напряжение по данным судна:")
                visible: _batteryFactGroup && _batteryFactGroup.voltage.value !== 0
            }
            QGCLabel {
                text:    _batteryFactGroup ? _batteryFactGroup.voltage.valueString : ""
                visible: _batteryFactGroup && _batteryFactGroup.voltage.value !== 0
            }

            QGCLabel { text: qsTr("Множитель напряжения:") }
            FactLabel { fact: batParams.battVoltMult }
        }

        QGCButton {
            text:    qsTr("Рассчитать и задать")
            enabled: _batteryFactGroup && _batteryFactGroup.voltage.value !== 0

            onClicked: {
                let measuredVoltageValue = parseFloat(measuredVoltage.text)
                if (measuredVoltageValue === 0 || isNaN(measuredVoltageValue)) {
                    return
                }
                let newVoltageMultiplier = (measuredVoltageValue * batParams.battVoltMult.value) / _batteryFactGroup.voltage.value
                if (newVoltageMultiplier > 0) {
                    batParams.battVoltMult.value = newVoltageMultiplier
                }
            }
        }
    }
}
