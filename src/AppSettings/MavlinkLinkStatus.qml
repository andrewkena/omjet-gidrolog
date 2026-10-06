import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SettingsGroupLayout {
    Layout.fillWidth:   true
    heading:            qsTr("Состояние канала (текущее судно)")

    property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property string _notConnectedStr: qsTr("Не подключено")

    LabelledLabel {
        Layout.fillWidth:   true
        label:              qsTr("Отправлено сообщений (расчётно)")
        labelText:          _activeVehicle ? _activeVehicle.mavlinkSentCount : _notConnectedStr
    }

    LabelledLabel {
        Layout.fillWidth:   true
        label:              qsTr("Получено сообщений")
        labelText:          _activeVehicle ? _activeVehicle.mavlinkReceivedCount : _notConnectedStr
    }

    LabelledLabel {
        Layout.fillWidth:   true
        label:              qsTr("Потеряно сообщений")
        labelText:          _activeVehicle ? _activeVehicle.mavlinkLossCount : _notConnectedStr
    }

    LabelledLabel {
        Layout.fillWidth:   true
        label:              qsTr("Доля потерь")
        labelText:          _activeVehicle ? _activeVehicle.mavlinkLossPercent.toFixed(0) + '%' : _notConnectedStr
    }

    LabelledLabel {
        Layout.fillWidth:   true
        label:              qsTr("Подпись")
        labelText:          _activeVehicle ? _activeVehicle.signingController.signingStatus.statusText : _notConnectedStr
    }

    LabelledLabel {
        Layout.fillWidth:   true
        label:              qsTr("Ключ подписи")
        labelText:          _activeVehicle && _activeVehicle.signingController.signingStatus.keyName !== ""
                                ? _activeVehicle.signingController.signingStatus.keyName
                                : qsTr("Нет")
        visible:            _activeVehicle && _activeVehicle.signingController.signingStatus.enabled
    }

    LabelledLabel {
        Layout.fillWidth:   true
        label:              qsTr("Подписанные потоки")
        labelText:          _activeVehicle ? _activeVehicle.signingController.signingStatus.streamCount : _notConnectedStr
        visible:            _activeVehicle && _activeVehicle.signingController.signingStatus.enabled
    }
}
