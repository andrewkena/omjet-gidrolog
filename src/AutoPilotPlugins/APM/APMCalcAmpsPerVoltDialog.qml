import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.FactControls
import QGroundControl.Controls

QGCPopupDialog {
    id:         popupDialog
    title:      qsTr("Расчёт ампер на вольт")
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
            text:                   qsTr("Измерьте ток внешним амперметром и введите значение ниже. Нажмите «Рассчитать», чтобы задать новое значение ампер на вольт.")
        }

        QGCLabel {
            Layout.preferredWidth:  gridLayout.width
            wrapMode:               Text.WordWrap
            visible:                !_batteryFactGroup || _batteryFactGroup.current.value === 0
            text:                   qsTr("Нет телеметрии тока. Подключитесь к судну с включённой батареей для автоматического расчёта.")
            color:                  qgcPal.warningText
        }

        GridLayout {
            id:         gridLayout
            columns:    2

            QGCLabel { text: qsTr("Измеренный ток:") }
            QGCTextField { id: measuredCurrent; numericValuesOnly: true }

            QGCLabel {
                text:    qsTr("Ток по данным судна:")
                visible: _batteryFactGroup && _batteryFactGroup.current.value !== 0
            }
            QGCLabel {
                text:    _batteryFactGroup ? _batteryFactGroup.current.valueString : ""
                visible: _batteryFactGroup && _batteryFactGroup.current.value !== 0
            }

            QGCLabel { text: qsTr("Ампер на вольт:") }
            FactLabel { fact: batParams.battAmpPerVolt }
        }

        QGCButton {
            text:    qsTr("Рассчитать и задать")
            enabled: _batteryFactGroup && _batteryFactGroup.current.value !== 0

            onClicked: {
                let measuredCurrentValue = parseFloat(measuredCurrent.text)
                if (measuredCurrentValue === 0 || isNaN(measuredCurrentValue)) {
                    return
                }
                let newAmpsPerVolt = (measuredCurrentValue * batParams.battAmpPerVolt.value) / _batteryFactGroup.current.value
                if (newAmpsPerVolt !== 0) {
                    batParams.battAmpPerVolt.value = newAmpsPerVolt
                }
            }
        }
    }
}
