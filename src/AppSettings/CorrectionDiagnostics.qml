pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SettingsGroupLayout {
    id: root

    property GPSCorrectionManager corrections: QGroundControl.gpsManager.corrections

    function destinationName(destinationId: string): string {
        if (destinationId === "ntripUdp")
            return qsTr("Выход NTRIP по UDP");
        if (destinationId === "mavlink")
            return qsTr("Борта");
        if (destinationId.startsWith("mavlink/"))
            return qsTr("Канал борта %1").arg(destinationId.slice(8));
        return destinationId || qsTr("Не выбрано");
    }

    function reasonName(reason) {
        switch (reason) {
        case GPSCorrectionEventModel.None:
            return "";
        case GPSCorrectionEventModel.InactiveSource:
            return qsTr("Неактивный источник");
        case GPSCorrectionEventModel.SessionMismatch:
            return qsTr("Прошлый сеанс источника");
        case GPSCorrectionEventModel.InvalidTimestamp:
            return qsTr("Неверное время приёма");
        case GPSCorrectionEventModel.Expired:
            return qsTr("Устарело");
        case GPSCorrectionEventModel.MessageFiltered:
            return qsTr("Отфильтровано");
        case GPSCorrectionEventModel.NotSelected:
            return qsTr("Источник не выбран");
        case GPSCorrectionEventModel.DestinationUnavailable:
            return qsTr("Получатель недоступен");
        case GPSCorrectionEventModel.QueueFull:
            return qsTr("Очередь заполнена");
        case GPSCorrectionEventModel.InvalidFrame:
            return qsTr("Неверный кадр");
        case GPSCorrectionEventModel.Cancelled:
            return qsTr("Подключение отменено");
        case GPSCorrectionEventModel.SourceChanged:
            return qsTr("Источник сменился");
        case GPSCorrectionEventModel.WriteFailed:
            return qsTr("Ошибка записи");
        case GPSCorrectionEventModel.PartialWrite:
            return qsTr("Неполная запись");
        case GPSCorrectionEventModel.InvalidDelivery:
            return qsTr("Отчёт о доставке без пары");
        case GPSCorrectionEventModel.DeliveryUnconfirmed:
            return qsTr("Соединение закрылось до результата записи");
        case GPSCorrectionEventModel.DiagnosticsBackpressure:
            return qsTr("Учёт доставки переполнен");
        default:
            return qsTr("Неизвестно");
        }
    }

    function sourceName(source) {
        switch (source) {
        case GPSCorrectionSettings.LocalReceiver:
            return qsTr("Локальная базовая станция");
        case GPSCorrectionSettings.Ntrip:
            return qsTr("NTRIP");
        case GPSCorrectionSettings.Udp:
            return qsTr("UDP");
        default:
            return qsTr("Без категории");
        }
    }

    function stageName(stage) {
        switch (stage) {
        case GPSCorrectionEventModel.Received:
            return qsTr("Принято");
        case GPSCorrectionEventModel.Validated:
            return qsTr("Проверено");
        case GPSCorrectionEventModel.Selected:
            return qsTr("Выбрано");
        case GPSCorrectionEventModel.Queued:
            return qsTr("В очереди");
        case GPSCorrectionEventModel.Written:
            return qsTr("Записано");
        case GPSCorrectionEventModel.Unconfirmed:
            return qsTr("Без подтверждения");
        case GPSCorrectionEventModel.Dropped:
            return qsTr("Отброшено");
        default:
            return qsTr("Неизвестно");
        }
    }

    heading: qsTr("Диагностика поправок")
    objectName: "correctionDiagnostics"

    QGCLabel {
        Layout.fillWidth: true
        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 50
        objectName: "correctionSelectionStatus"
        text: root.corrections.sourceInstances.some(source => source.selected)
              ? qsTr("Текущие потоки поправок:")
              : qsTr("Для бортов не выбран свежий поток.")
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.corrections.sourceInstances

        QGCLabel {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 50
            objectName: "correctionStreamState_" + modelData.source + "_" + modelData.instanceId
            text: {
                let status;
                if (modelData.selected)
                    status = qsTr("Выбран для бортов; свежий");
                else if (modelData.usable)
                    status = qsTr("Свежий; не выбран для бортов");
                else if (modelData.active)
                    status = qsTr("Активен; ожидание свежих поправок");
                else
                    status = qsTr("Недоступно");
                return qsTr("%1 — %2: %3").arg(root.sourceName(modelData.source))
                                         .arg(modelData.instanceId || qsTr("Поток по умолчанию")).arg(status);
            }
            wrapMode: Text.WordWrap
        }
    }

    QGCLabel {
        Layout.fillWidth: true
        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 50
        text: qsTr("«В очереди» — байты переданы на выход. «Записано» — байты дошли до транспорта; это не подтверждает, что приёмник применил поправки или получил решение. Запись на борт не подтверждается.")
        wrapMode: Text.WordWrap
    }

    QGCLabel {
        Layout.fillWidth: true
        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 50
        text: qsTr("Принятые/отброшенные байты считаются по кандидатам кадров, а не по сырому трафику. Восстановленные кадры могут пересекаться с отброшенными. События отбрасывания считают потери отдельно на выборе, приёме и доставке; один кадр может учитываться несколько раз.")
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.corrections.sources

        QGCLabel {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 50
            text: qsTr("%1 — кадры: принято %2, проверено %3, выбрано %4, в очереди %5, записано %6; отбрасываний %7").arg(root.sourceName(modelData.source)).arg(modelData.receivedFrames).arg(modelData.validatedFrames).arg(modelData.selectedFrames).arg(modelData.queuedFrames).arg(modelData.writtenFrames).arg(modelData.droppedFrames)
            wrapMode: Text.WordWrap
        }
    }

    Repeater {
        model: root.corrections.destinations

        QGCLabel {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 50
            objectName: "correctionDestination_" + modelData.destinationId
            text: qsTr("%1 — в очереди %2 Б, записано %3, отброшено %4 Б, ожидает %5 Б, без подтверждения %6 Б").arg(root.destinationName(modelData.destinationId)).arg(modelData.queuedBytes).arg(modelData.reportsWrites ? qsTr("%1 Б").arg(modelData.writtenBytes) : qsTr("без подтверждения")).arg(modelData.droppedBytes).arg(modelData.pendingBytes).arg(modelData.unconfirmedBytes)
            wrapMode: Text.WordWrap
        }
    }

    QGCCheckBox {
        id: historyToggle

        objectName: "correctionHistoryToggle"
        text: qsTr("Показать последние события поправок")
    }

    Loader {
        Layout.fillWidth: true
        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 50
        active: historyToggle.checked
        visible: active

        sourceComponent: ListView {
            clip: true
            implicitHeight: ScreenTools.defaultFontPixelHeight * 16
            model: root.corrections.events
            objectName: "correctionEventHistory"
            reuseItems: true
            spacing: ScreenTools.defaultFontPixelHeight / 2

            delegate: QGCLabel {
                required property double bytes
                required property string destinationId
                required property double destinationSession
                required property double eventSequence
                required property int reason
                required property int source
                required property string sourceInstance
                required property double sourceSession
                required property int stage

                text: qsTr("%1. %2 — %3, %4 Б%5\nИсточник: %6 (сеанс %7); получатель: %8 (сеанс %9)").arg(eventSequence).arg(root.sourceName(source)).arg(root.stageName(stage)).arg(bytes).arg(reason === GPSCorrectionEventModel.None ? "" : qsTr(" — %1").arg(root.reasonName(reason))).arg(sourceInstance || root.sourceName(source)).arg(sourceSession).arg(root.destinationName(destinationId)).arg(destinationSession)
                width: ListView.view.width
                wrapMode: Text.WordWrap
            }
        }
    }
}
