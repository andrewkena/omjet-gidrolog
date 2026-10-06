pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SettingsGroupLayout {
    id: _signingKeyManager

    Layout.fillWidth: true
    heading:            qsTr("Подпись MAVLink 2")
    headingDescription: qsTr("Ключи подписи передавайте на судно только по защищённому каналу (например, USB).")

    property Vehicle _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    // Wipe clipboard 30s after Export so a casually-copied key doesn't linger across paste targets.
    Timer {
        id: clipboardWipeTimer
        interval: 30000
        repeat: false
        onTriggered: QGroundControl.copyToClipboard("")
    }

    QGCPopupDialogFactory {
        id: addKeyDialogFactory
        dialogComponent: addKeyDialogComponent
    }

    Component {
        id: addKeyDialogComponent

        QGCPopupDialog {
            id:                     addKeyDialog
            title:                  qsTr("Добавить ключ подписи")
            buttons:                Dialog.Ok | Dialog.Cancel
            acceptButtonEnabled:    keyNameField.text !== "" &&
                                    (addKeyDialog.useRawKey
                                        ? rawKeyField.text.length === 64
                                        : passphraseField.text.length >= addKeyDialog._minPassphraseLength)

            property bool useRawKey: false
            readonly property int _minPassphraseLength: 8

            onAccepted: {
                let ok = false
                if (addKeyDialog.useRawKey) {
                    ok = QGroundControl.mavlinkSigningKeys.addRawKey(keyNameField.text, rawKeyField.text)
                } else {
                    ok = QGroundControl.mavlinkSigningKeys.addKey(keyNameField.text, passphraseField.text)
                }
                if (!ok) {
                    addKeyDialog.preventClose = true
                    errorLabel.text = qsTr("Не удалось добавить ключ. Возможно, такое имя уже есть или данные введены неверно.")
                }
            }

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCLabel { text: qsTr("Имя ключа") }
                QGCTextField {
                    id:                     keyNameField
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 30
                    placeholderText:        qsTr("Введите понятное имя")
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCRadioButton {
                        text:       qsTr("Парольная фраза")
                        checked:    !addKeyDialog.useRawKey
                        onClicked:  addKeyDialog.useRawKey = false
                    }
                    QGCRadioButton {
                        text:       qsTr("Ключ (hex)")
                        checked:    addKeyDialog.useRawKey
                        onClicked:  addKeyDialog.useRawKey = true
                    }
                }

                QGCTextField {
                    id:                     passphraseField
                    visible:                !addKeyDialog.useRawKey
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 30
                    placeholderText:        qsTr("Введите парольную фразу (не менее %1 симв.)").arg(addKeyDialog._minPassphraseLength)
                    echoMode:               TextInput.Password
                    inputMethodHints:       Qt.ImhNoPredictiveText
                }

                QGCLabel {
                    visible:    !addKeyDialog.useRawKey && passphraseField.text.length > 0 && passphraseField.text.length < addKeyDialog._minPassphraseLength
                    text:       qsTr("Парольная фраза слишком короткая (%1/%2)").arg(passphraseField.text.length).arg(addKeyDialog._minPassphraseLength)
                    color:      QGroundControl.globalPalette.warningText
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                RowLayout {
                    visible:    addKeyDialog.useRawKey
                    spacing:    ScreenTools.defaultFontPixelWidth / 2

                    QGCTextField {
                        id:                     rawKeyField
                        Layout.fillWidth:       true
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 30
                        placeholderText:        qsTr("64 hex-символа")
                        maximumLength:          64
                        inputMethodHints:       Qt.ImhNoPredictiveText
                        validator:              RegularExpressionValidator { regularExpression: /[0-9a-fA-F]*/ }
                    }

                    QGCButton {
                        text:       qsTr("Сгенерировать")
                        onClicked:  rawKeyField.text = QGroundControl.mavlinkSigningKeys.generateRandomHexKey()
                    }
                }

                QGCLabel {
                    visible:    addKeyDialog.useRawKey && rawKeyField.text.length > 0 && rawKeyField.text.length !== 64
                    text:       qsTr("%1/64 hex-символов").arg(rawKeyField.text.length)
                    color:      QGroundControl.globalPalette.warningText
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                QGCLabel {
                    id:             errorLabel
                    visible:        text !== ""
                    color:          QGroundControl.globalPalette.warningText
                    font.pointSize: ScreenTools.smallFontPointSize
                    Layout.fillWidth: true
                    wrapMode:       Text.WordWrap
                }
            }
        }
    }

    LabelledLabel {
        Layout.fillWidth:   true
        label:              qsTr("Активный ключ")
        labelText:          _signingKeyManager._activeVehicle && _signingKeyManager._activeVehicle.signingController.signingStatus.keyName !== ""
                                ? _signingKeyManager._activeVehicle.signingController.signingStatus.keyName
                                : qsTr("Нет")
        visible:            _signingKeyManager._activeVehicle
    }

    Repeater {
        model: QGroundControl.mavlinkSigningKeys.keys

        RowLayout {
            id: keyDelegate
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            required property var object
            required property int index

            property string _keyName:           keyDelegate.object.name
            property bool _keyIsActive:         { void(QGroundControl.mavlinkSigningKeys.keyUsageRevision); return QGroundControl.mavlinkSigningKeys.isKeyInUse(keyDelegate._keyName) }
            property bool _keyIsActiveVehicle:  _signingKeyManager._activeVehicle && _signingKeyManager._activeVehicle.signingController.signingStatus.keyName === keyDelegate._keyName
            property bool _anyKeyActive:        _signingKeyManager._activeVehicle && _signingKeyManager._activeVehicle.signingController.signingStatus.keyName !== ""
            property bool _otherKeyActive:      keyDelegate._anyKeyActive && !keyDelegate._keyIsActiveVehicle
            property bool _signingPending:      _signingKeyManager._activeVehicle && _signingKeyManager._activeVehicle.signingController.signingStatus.pending

            QGCLabel {
                text:               keyDelegate._keyName
                Layout.fillWidth:   true
            }

            // Quiet hint when a different key on this vehicle is the active one — explains why
            // Enable/Disable are both hidden on this row.
            QGCLabel {
                text:               qsTr("(активен другой ключ)")
                visible:            keyDelegate._otherKeyActive
                font.pointSize:     ScreenTools.smallFontPointSize
                opacity:            0.7
            }

            QGCButton {
                text:       keyDelegate._signingPending ? qsTr("Настройка…") : qsTr("Включить")
                visible:    !keyDelegate._anyKeyActive
                enabled:    _signingKeyManager._activeVehicle && !keyDelegate._signingPending
                onClicked: {
                    if (!_signingKeyManager._activeVehicle) {
                        return
                    }
                    const linkName = _signingKeyManager._activeVehicle.vehicleLinkManager
                                        ? _signingKeyManager._activeVehicle.vehicleLinkManager.primaryLinkName
                                        : qsTr("активный канал")
                    QGroundControl.showMessageDialog(
                        _signingKeyManager,
                        qsTr("Отправка ключа подписи"),
                        qsTr("Ключ «%1» будет передан на судно по каналу «%2». Продолжайте, только если канал защищён (USB или доверенная локальная сеть).").arg(keyDelegate._keyName).arg(linkName),
                        Dialog.Ok | Dialog.Cancel,
                        function () {
                            if (_signingKeyManager._activeVehicle) {
                                _signingKeyManager._activeVehicle.signingController.enable(keyDelegate._keyName)
                            }
                        })
                }
            }

            QGCButton {
                text:       keyDelegate._signingPending ? qsTr("Отключение…") : qsTr("Отключить")
                visible:    keyDelegate._keyIsActiveVehicle
                enabled:    _signingKeyManager._activeVehicle && !keyDelegate._signingPending
                onClicked: {
                    if (!_signingKeyManager._activeVehicle) {
                        return
                    }
                    // ArduPilot refuses SETUP_SIGNING while armed; disabling a flying vehicle leaves GCS unsigned vs. signed-required.
                    if (_signingKeyManager._activeVehicle.armed) {
                        QGroundControl.showMessageDialog(
                            _signingKeyManager,
                            qsTr("Отключить подпись при запущенном судне?"),
                            qsTr("Судно запущено. ArduPilot не отключает подпись на запущенном судне, а PX4 не примет команду без действительной подписи. Попытка, скорее всего, завершится тайм-аутом и оставит канал в неопределённом состоянии.\n\nСначала остановите судно."),
                            Dialog.Cancel)
                        return
                    }
                    _signingKeyManager._activeVehicle.signingController.disable()
                }
            }

            QGCButton {
                text:       qsTr("Экспорт")
                visible:    !keyDelegate._keyIsActive
                onClicked: {
                    let hex = QGroundControl.mavlinkSigningKeys.keyHexByName(keyDelegate._keyName)
                    if (hex !== "") {
                        QGroundControl.copyToClipboard(hex)
                        clipboardWipeTimer.restart()
                        QGroundControl.showMessageDialog(
                            _signingKeyManager,
                            qsTr("Экспорт ключа: %1").arg(keyDelegate._keyName),
                            qsTr("Ключ скопирован в буфер обмена. Сохраните его в надёжном месте — через 30 секунд буфер будет очищен."),
                            Dialog.Ok)
                    }
                }
            }

            QGCButton {
                text:       qsTr("Удалить")
                visible:    !keyDelegate._keyIsActive
                onClicked:  QGroundControl.showMessageDialog(
                                _signingKeyManager,
                                qsTr("Удаление ключа подписи"),
                                qsTr("Удалить ключ «%1»?\n\nЕсли этот ключ настроен на судне, связаться с ним по подписанному каналу будет невозможно. Введённые или сгенерированные ключи восстановить нельзя — при необходимости сначала сделайте экспорт.").arg(keyDelegate._keyName),
                                Dialog.Ok | Dialog.Cancel,
                                function () { QGroundControl.mavlinkSigningKeys.removeKey(keyDelegate._keyName) })
            }
        }
    }

    QGCLabel {
        text:       qsTr("Ключи не настроены")
        visible:    QGroundControl.mavlinkSigningKeys.keys.count === 0
    }

    QGCButton {
        text:       qsTr("Добавить ключ")
        onClicked:  addKeyDialogFactory.open()
    }
}
