pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SettingsGroupLayout {
    id: root

    required property var receiver
    required property var settings
    required property var baseFacts
    required property var autoConnectFact
    property var serialPorts: []
    property var serialBaudRates: []
    property var consent: QtObject { property bool allowed: false }

    readonly property int manufacturer: settings.baseReceiverManufacturers.rawValue
    readonly property int baseMode: settings.useFixedBasePosition.rawValue
    readonly property var presentation: receiver.capabilitiesForManufacturer(manufacturer)
    readonly property bool modeCompatible: presentation.passive
        || (baseMode === BaseModeDefinition.BaseFixed && presentation.rtkBase)
        || (baseMode === BaseModeDefinition.BaseSurveyIn && presentation.surveyIn)
        || (baseMode === BaseModeDefinition.BaseReceiverAveraging && presentation.receiverAveraging)
    readonly property bool _editable: !receiver.hasReceiver

    implicitWidth: ScreenTools.defaultFontPixelWidth * 56
    heading: qsTr("Настройки RTK GPS")

    onManufacturerChanged: clearConsent()
    onBaseModeChanged: clearConsent()
    onReceiverChanged: clearConsent()
    onSettingsChanged: clearConsent()
    Component.onDestruction: clearConsent()

    function clearConsent() {
        if (consent) {
            consent.allowed = false
        }
    }

    function connectSelectedReceiver() {
        const allowPersistentChanges = presentation.persistentConfiguration && consent.allowed
        clearConsent()
        return receiver.connectConfiguredGPS(allowPersistentChanges)
    }

    function saveCurrentBasePosition() {
        if (!baseFacts.canSaveCurrentBasePosition) {
            return false
        }
        const latitude = baseFacts.currentLatitude.rawValue
        const longitude = baseFacts.currentLongitude.rawValue
        const altitude = baseFacts.currentAltitude.rawValue
        const accuracy = baseFacts.currentAccuracy.rawValue
        if (![latitude, longitude, altitude, accuracy].every(Number.isFinite)
            || accuracy < 0 || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
            return false
        }
        settings.fixedBasePositionLatitude.rawValue = latitude
        settings.fixedBasePositionLongitude.rawValue = longitude
        settings.fixedBasePositionAltitude.rawValue = altitude
        settings.fixedBasePositionAccuracy.rawValue = accuracy
        return true
    }

    component Explanation: QGCLabel {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }

    component SettingField: ColumnLayout {
        id: field
        required property Fact fact
        property string label: fact.shortDescription

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: ScreenTools.defaultFontPixelHeight / 4

        Explanation { text: field.label }
        FactTextField {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            fact: field.fact
        }
    }

    component ModeButton: QGCRadioButton {
        id: button
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        focusPolicy: Qt.StrongFocus
        contentItem: QGCLabel {
            text: button.text
            color: button.textColor
            leftPadding: button.indicator.width + ScreenTools.defaultFontPixelWidth / 2
            wrapMode: Text.Wrap
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.autoConnectFact.userVisible
        Explanation { text: qsTr("Автоподключение известных приёмников") }
        FactCheckBoxSlider {
            text: ""
            Accessible.name: qsTr("Автоподключение известных приёмников")
            fact: root.autoConnectFact
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.settings.baseReceiverManufacturers.userVisible
        Explanation { text: qsTr("Приёмник / настройки") }
        FactComboBox {
            objectName: "rtkManufacturer"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            fact: root.settings.baseReceiverManufacturers
            enabled: root._editable
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.receiver.serialSupported
        Explanation { text: qsTr("Последовательный порт") }
        QGCComboBox {
            objectName: "rtkSerialDevice"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            enabled: root._editable && root.serialPorts.length > 0
            model: root.serialPorts.length > 0 ? root.serialPorts : [qsTr("<нет доступных>")]
            currentIndex: root.serialPorts.length > 0
                          ? root.serialPorts.indexOf(root.settings.serialDevice.valueString) : 0
            onActivated: (index) => {
                if (index >= 0 && index < root.serialPorts.length) {
                    root.settings.serialDevice.rawValue = root.serialPorts[index]
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.receiver.serialSupported
        Explanation { text: qsTr("Скорость порта") }
        QGCComboBox {
            id: baudCombo
            objectName: "rtkSerialBaudRate"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            enabled: root._editable

            readonly property var rates: root.serialBaudRates.filter(rate => Number(rate) >= 1200 && Number(rate) <= 4000000)
            property bool customSelected: rates.indexOf(root.settings.serialBaudRate.valueString) < 0

            model: rates.concat([qsTr("Другая")])
            currentIndex: customSelected ? rates.length : rates.indexOf(root.settings.serialBaudRate.valueString)
            onActivated: (index) => {
                customSelected = index === rates.length
                if (index >= 0 && index < rates.length) {
                    root.settings.serialBaudRate.rawValue = Number(rates[index])
                }
            }
        }
    }

    SettingField {
        label: qsTr("Своя скорость порта")
        fact: root.settings.serialBaudRate
        visible: root.receiver.serialSupported && baudCombo.customSelected
        enabled: root._editable
    }

    Explanation {
        visible: root._editable
        text: !root.presentation.specificReceiver
              ? qsTr("Выберите тип приёмника, порт и скорость, чтобы подключиться вручную.")
              : qsTr("Подключается только выбранный приёмник. Тип USB-адаптера не определяет производителя GNSS. Ручное подключение отключает автоподключение.")
    }

    Explanation {
        visible: root.presentation.passive
        text: qsTr("Пассивный вход не настраивает приёмник. Настройте вывод RTCM/NMEA заранее и выберите его скорость порта. Статус съёмки базы не определяется.")
    }

    Explanation {
        objectName: "rtkPersistentConfigurationWarning"
        visible: root.presentation.restartOnConnect
        text: qsTr("Без разрешения на сохранение роль и настройки базы Quectel должны заранее совпадать с сохранёнными. При подключении приёмник перезапускается. Съёмка базы считает принятые наблюдения 1 Гц; предел точности фильтрует каждое наблюдение и не гарантирует итоговую точность.")
    }

    Explanation {
        visible: root.presentation.surveyMaySavePosition && root.baseMode === BaseModeDefinition.BaseSurveyIn
        text: qsTr("Приёмник Quectel может сам сохранить полученные координаты базы в своей памяти.")
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.presentation.rtkBase
        enabled: root._editable

        ModeButton {
            objectName: "rtkSurveyMode"
            text: qsTr("Съёмка базы (Survey-In)")
            checked: root.baseMode === BaseModeDefinition.BaseSurveyIn
            onClicked: root.settings.useFixedBasePosition.rawValue = BaseModeDefinition.BaseSurveyIn
            visible: root.presentation.surveyIn
        }
        ModeButton {
            objectName: "rtkFixedMode"
            text: qsTr("Задать координаты")
            checked: root.baseMode === BaseModeDefinition.BaseFixed
            onClicked: root.settings.useFixedBasePosition.rawValue = BaseModeDefinition.BaseFixed
        }
        ModeButton {
            text: qsTr("Усреднение приёмником")
            checked: root.baseMode === BaseModeDefinition.BaseReceiverAveraging
            onClicked: root.settings.useFixedBasePosition.rawValue = BaseModeDefinition.BaseReceiverAveraging
            visible: root.presentation.receiverAveraging
        }
    }

    Explanation {
        visible: !root.modeCompatible
        text: qsTr("Выбранный режим базы не поддерживается этим приёмником. Выберите поддерживаемый режим.")
    }

    Explanation {
        visible: root.presentation.receiverAveraging && root.baseMode === BaseModeDefinition.BaseReceiverAveraging
        text: qsTr("Приёмник усредняет координаты в течение максимального времени. Это не съёмка базы с контролем точности, точность не гарантируется.")
    }

    SettingField {
        label: qsTr("Максимальное время усреднения")
        fact: root.settings.receiverAveragingDuration
        visible: root.presentation.receiverAveraging && root.baseMode === BaseModeDefinition.BaseReceiverAveraging
        enabled: root._editable
    }

    FactSlider {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        label: root.presentation.observationAccuracyFilter ? qsTr("Предел точности наблюдения") : qsTr("Точность")
        fact: root.settings.surveyInAccuracyLimit
        majorTickStepSize: 0.1
        enabled: root._editable
        visible: root.baseMode === BaseModeDefinition.BaseSurveyIn
                 && root.settings.surveyInAccuracyLimit.userVisible && root.presentation.surveyAccuracy
    }

    FactSlider {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        label: root.presentation.acceptedObservationTime ? qsTr("Принятое время наблюдений") : qsTr("Мин. длительность")
        fact: root.settings.surveyInMinObservationDuration
        majorTickStepSize: 10
        enabled: root._editable
        visible: root.baseMode === BaseModeDefinition.BaseSurveyIn
                 && root.settings.surveyInMinObservationDuration.userVisible && root.presentation.surveyDuration
    }

    SettingField {
        fact: root.settings.fixedBasePositionLatitude
        enabled: root._editable
        visible: root.baseMode === BaseModeDefinition.BaseFixed && root.presentation.rtkBase
    }
    SettingField {
        fact: root.settings.fixedBasePositionLongitude
        enabled: root._editable
        visible: root.baseMode === BaseModeDefinition.BaseFixed && root.presentation.rtkBase
    }
    SettingField {
        fact: root.settings.fixedBasePositionAltitude
        enabled: root._editable
        visible: root.baseMode === BaseModeDefinition.BaseFixed && root.presentation.rtkBase
    }
    SettingField {
        fact: root.settings.fixedBasePositionAccuracy
        enabled: root._editable
        visible: root.baseMode === BaseModeDefinition.BaseFixed && root.presentation.fixedBaseAccuracy
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.presentation.rtkBase
        Explanation {
            text: qsTr("Сохранить текущие координаты базы для последующего подключения с заданными координатами. Режим работающего приёмника не меняется.")
        }
        QGCButton {
            objectName: "rtkSaveBasePosition"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            wrapMode: Text.Wrap
            focusPolicy: Qt.StrongFocus
            text: root.baseFacts.canSaveCurrentBasePosition ? qsTr("Сохранить координаты базы")
                  : !root.baseFacts.valid.rawValue ? qsTr("Ещё не готово")
                  : !Number.isFinite(root.baseFacts.currentAccuracy.rawValue)
                    || root.baseFacts.currentAccuracy.rawValue < 0 ? qsTr("Точность недоступна")
                  : qsTr("Неверные координаты базы")
            enabled: root.baseFacts.canSaveCurrentBasePosition
            onClicked: root.saveCurrentBasePosition()
        }
    }

    QGCCheckBox {
        id: persistenceCheckbox
        objectName: "rtkPersistentChangesCheckBox"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: qsTr("Разрешить запись во флеш и перезапуск")
        focusPolicy: Qt.StrongFocus
        visible: root.receiver.serialSupported && root.presentation.persistentConfiguration
        enabled: root._editable
        checked: root.consent.allowed
        onClicked: root.consent.allowed = checked
        contentItem: QGCLabel {
            text: persistenceCheckbox.text
            color: persistenceCheckbox.textColor
            leftPadding: persistenceCheckbox.indicator.width + persistenceCheckbox.spacing
            wrapMode: Text.Wrap
        }
    }

    Explanation {
        objectName: "rtkPersistentConsentWarning"
        visible: root.receiver.serialSupported && root.presentation.persistentConfiguration
        text: qsTr("Только для этого подключения разрешить программе записать роль и настройки базы во флеш приёмника и перезапустить его. Изменения могут сохраниться, даже если переподключение не удастся. Сброс к заводским настройкам не выполняется. Разрешение сбрасывается после каждой попытки и не используется автоподключением.")
    }

    QGCButton {
        objectName: "rtkConnectButton"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        wrapMode: Text.Wrap
        focusPolicy: Qt.StrongFocus
        text: root.receiver.hasReceiver ? qsTr("Отключить") : qsTr("Подключить")
        visible: root.receiver.serialSupported
        enabled: root.receiver.hasReceiver || (root.presentation.specificReceiver && root.modeCompatible)
        onClicked: {
            if (root.receiver.hasReceiver) {
                root.clearConsent()
                root.receiver.disconnectConfiguredGPS()
            } else {
                root.connectSelectedReceiver()
            }
        }
    }

    Connections {
        target: root.receiver
        function onReceiverChanged() { root.clearConsent() }
    }
    Connections {
        target: root.settings.serialDevice
        function onRawValueChanged() { root.clearConsent() }
    }
    Connections {
        target: root.settings.serialBaudRate
        function onRawValueChanged() { root.clearConsent() }
    }
}
