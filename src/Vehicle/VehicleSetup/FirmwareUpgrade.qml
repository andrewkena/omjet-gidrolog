import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SetupPage {
    id:             firmwarePage
    pageComponent:  firmwarePageComponent
    pageName:       qsTr("Прошивка")
    showAdvanced:   globals.activeVehicle && globals.activeVehicle.apmFirmware

    Component {
        id: firmwarePageComponent

        ColumnLayout {
            width:   availableWidth
            height:  availableHeight
            spacing: ScreenTools.defaultFontPixelHeight

            // Those user visible strings are hard to translate because we can't send the
            // HTML strings to translation as this can create a security risk. we need to find
            // a better way to highlight them, or use less highlights.

            // User visible strings
            readonly property string title:             qsTr("Прошивка") // Popup dialog title
            readonly property string highlightPrefix:   "<font color=\"" + qgcPal.warningText + "\">"
            readonly property string highlightSuffix:   "</font>"
            readonly property string welcomeText:       qsTr("Программа может обновить прошивку автопилота Pixhawk и радиомодемов SiK.").arg(QGroundControl.appName)
            readonly property string welcomeTextSingle: qsTr("Обновить прошивку автопилота до последней версии")
            readonly property string plugInText:        highlightPrefix + qsTr("Подключите устройство") + highlightSuffix + qsTr(" по USB, выберите его ниже и нажмите ") + highlightPrefix + qsTr("Прошить") + highlightSuffix + "."
            readonly property string unplugReplugText:  highlightPrefix + qsTr("Отключите устройство и подключите снова, чтобы войти в режим загрузчика.") + highlightSuffix
            readonly property string flashFailText:     qsTr("Если прошить не удалось, подключите ") + highlightPrefix + qsTr("напрямую") + highlightSuffix + qsTr(" к USB-порту компьютера, не через хаб. ") +
                                                        qsTr("Питание должно идти только по USB, ") + highlightPrefix + qsTr("не от батареи") + highlightSuffix + "."

            readonly property int _defaultFimwareTypePX4:   12
            readonly property int _defaultFimwareTypeAPM:   3

            readonly property int _boardTypePixhawk:    0
            readonly property int _boardTypeSiKRadio:   1

            property var    _firmwareUpgradeSettings:   QGroundControl.settingsManager.firmwareUpgradeSettings
            property var    _defaultFirmwareFact:       _firmwareUpgradeSettings.defaultFirmwareType
            property bool   _defaultFirmwareIsPX4:      true

            property string firmwareWarningMessage
            property bool   firmwareWarningMessageVisible:  false
            property string firmwareName
            property bool   _flashStarted:              false  ///< true: user has clicked Flash, suppress further preselection
            property bool   _cancellable:               true   ///< false once erase has started — past the point of clean cancellation
            property string _selectedSystemLocation
            property string _selectedDisplayName                ///< snapshot of chosen port's label, used while flashing

            property bool _singleFirmwareMode:          QGroundControl.corePlugin.options.firmwareUpgradeSingleURL.length != 0   ///< true: running in special single firmware download mode

            function setupPageCompleted() {
                controller.startBoardSearch()
                _defaultFirmwareIsPX4 = _defaultFirmwareFact.rawValue === _defaultFimwareTypePX4 // we don't want this to be bound and change as radios are selected
                _lastKnownCount = 0
            }

            property int _lastKnownCount: 0

            function _recognizedBoardCount() {
                var ports = controller.availablePorts
                var count = 0
                for (var i = 0; i < ports.length; i++) {
                    if (ports[i].boardType === _boardTypePixhawk || ports[i].boardType === _boardTypeSiKRadio) {
                        count++
                    }
                }
                return count
            }

            function _preselectIndex() {
                var ports = controller.availablePorts
                if (ports.length === 0) {
                    return -1
                }
                for (var i = 0; i < ports.length; i++) {
                    if (ports[i].boardType === _boardTypePixhawk) {
                        return i
                    }
                }
                for (var j = 0; j < ports.length; j++) {
                    if (ports[j].boardType === _boardTypeSiKRadio) {
                        return j
                    }
                }
                // No recognized device found
                return -1
            }

            function _refreshSelection() {
                if (_flashStarted || portCombo.popup.visible) {
                    return
                }
                var knownCount = _recognizedBoardCount()
                if (knownCount > 1 && _lastKnownCount <= 1) {
                    statusTextArea.append(highlightPrefix + qsTr("Найдено несколько устройств. Выберите нужное в списке.") + highlightSuffix)
                }
                _lastKnownCount = knownCount
                var ports = controller.availablePorts
                if (ports.length === 0) {
                    portCombo.currentIndex = -1
                    _selectedSystemLocation = ""
                    return
                }
                if (_selectedSystemLocation !== "") {
                    // Check if the current selection is already a recognized device
                    var currentIsRecognized = false
                    for (var i = 0; i < ports.length; i++) {
                        if (ports[i].systemLocation === _selectedSystemLocation) {
                            if (ports[i].boardType === _boardTypePixhawk || ports[i].boardType === _boardTypeSiKRadio) {
                                currentIsRecognized = true
                            }
                            break
                        }
                    }
                    // Only keep the current selection if it is a recognized device;
                    // otherwise fall through to preselect the first recognized device
                    if (currentIsRecognized) {
                        for (var j = 0; j < ports.length; j++) {
                            if (ports[j].systemLocation === _selectedSystemLocation) {
                                portCombo.currentIndex = j
                                return
                            }
                        }
                    }
                }
                portCombo.currentIndex = _preselectIndex()
                if (portCombo.currentIndex >= 0) {
                    _selectedSystemLocation = ports[portCombo.currentIndex].systemLocation
                }
            }


            FirmwareUpgradeController {
                id:             controller
                progressBar:    progressBar
                statusLog:      statusTextArea

                property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

                onActiveVehicleChanged: {
                    if (!globals.activeVehicle && !_flashStarted) {
                        statusTextArea.append(plugInText)
                    }
                }

                onAvailablePortsChanged: _refreshSelection()

                onBoardGone: {
                    if (_flashStarted) {
                        statusTextArea.append(highlightPrefix + qsTr("Устройство отключено — ждём его появления в режиме загрузчика...") + highlightSuffix)
                    }
                }

                onBoardFound: {
                    if (_flashStarted) {
                        statusTextArea.append(highlightPrefix + qsTr("Найдено устройство") + highlightSuffix + ": " + controller.boardType + " (" + controller.boardPort + ")")
                        if (QGroundControl.multiVehicleManager.activeVehicle) {
                            QGroundControl.multiVehicleManager.activeVehicle.vehicleLinkManager.autoDisconnect = true
                        }
                    }
                }

                onShowFirmwareSelectDlg:    firmwareSelectDialogFactory.open()
                onEraseStarted:             _cancellable = false
                onError: {
                    statusTextArea.append(flashFailText)
                    _flashStarted = false
                    _cancellable = true
                }
                onFlashComplete: {
                    _flashStarted = false
                    _cancellable = true
                }
            }

            QGCPopupDialogFactory {
                id: firmwareSelectDialogFactory

                dialogComponent: firmwareSelectDialogComponent
            }

            Component {
                id: firmwareSelectDialogComponent

                QGCPopupDialog {
                    id:         firmwareSelectDialog
                    title:      qsTr("Прошивка")
                    buttons:    Dialog.Ok | Dialog.Cancel

                    property bool showFirmwareTypeSelection:    _advanced.checked

                    QGCFileDialog {
                        id:                 customFirmwareDialog
                        title:              qsTr("Выберите файл прошивки")
                        nameFilters:        [qsTr("Файлы прошивки (*.px4 *.apj *.bin *.ihx)"), qsTr("Все файлы (*)")]
                        folder:             QGroundControl.settingsManager.appSettings.logSavePath
                        onAcceptedForLoad: (file) => {
                            controller.flashFirmwareUrl(file)
                            close()
                            firmwareSelectDialog.close()
                        }
                    }

                    function firmwareVersionChanged(model) {
                        firmwareWarningMessageVisible = false
                        // All of this bizarre, setting model to null and index to 1 and then to 0 is to work around
                        // strangeness in the combo box implementation. This sequence of steps correctly changes the combo model
                        // without generating any warnings and correctly updates the combo text with the new selection.
                        firmwareBuildTypeCombo.model = null
                        firmwareBuildTypeCombo.model = model
                        firmwareBuildTypeCombo.currentIndex = 1
                        firmwareBuildTypeCombo.currentIndex = 0
                    }

                    function updatePX4VersionDisplay() {
                        var versionString = ""
                        if (_advanced.checked) {
                            switch (controller.selectedFirmwareBuildType) {
                            case FirmwareUpgradeController.StableFirmware:
                                versionString = controller.px4StableVersion
                                break
                            case FirmwareUpgradeController.BetaFirmware:
                                versionString = controller.px4BetaVersion
                                break
                            }
                        } else {
                            versionString = controller.px4StableVersion
                        }
                        px4FlightStackRadio.text = qsTr("PX4 Pro ") + versionString
                        //px4FlightStackRadio2.text = qsTr("PX4 Pro ") + versionString
                    }

                    Component.onCompleted: {
                        firmwarePage.advanced = false
                        firmwarePage.showAdvanced = false
                        updatePX4VersionDisplay()
                    }

                    Connections {
                        target:     controller
                        onError:    reject()
                    }

                    onAccepted: {
                        if (_singleFirmwareMode) {
                            if (controller.selectedFirmwareBuildType === FirmwareUpgradeController.CustomFirmware) {
                                // User picked Custom but cancelled the auto-opened picker; reopen it
                                // and keep this dialog open until a file is chosen or Cancel is clicked.
                                customFirmwareDialog.openForLoad()
                                firmwareSelectDialog.preventClose = true
                            } else {
                                controller.flashSingleFirmwareMode(controller.selectedFirmwareBuildType)
                            }
                        } else {
                            var firmwareBuildType = firmwareBuildTypeCombo.model.get(firmwareBuildTypeCombo.currentIndex).firmwareType
                            var vehicleType = FirmwareUpgradeController.DefaultVehicleFirmware

                            var stack = apmFlightStack.checked ? FirmwareUpgradeController.AutoPilotStackAPM : FirmwareUpgradeController.AutoPilotStackPX4
                            if (apmFlightStack.checked) {
                                if (firmwareBuildType === FirmwareUpgradeController.CustomFirmware) {
                                    vehicleType = apmVehicleTypeCombo.currentIndex
                                } else {
                                    if (controller.apmFirmwareNames.length === 0) {
                                        // Not ready yet, or no firmware available
                                        QGroundControl.showMessageDialog(firmwarePage, firmwareSelectDialog.title, qsTr("Список прошивок ещё загружается или для выбранного нет прошивки."))
                                        firmwareSelectDialog.preventClose = true
                                        return
                                    }
                                    if (ardupilotFirmwareSelectionCombo.currentIndex == -1) {
                                        QGroundControl.showMessageDialog(firmwarePage, firmwareSelectDialog.title, qsTr("Выберите тип платы."))
                                        firmwareSelectDialog.preventClose = true
                                        return
                                    }

                                    var firmwareUrl = controller.apmFirmwareUrls[ardupilotFirmwareSelectionCombo.currentIndex]
                                    if (firmwareUrl == "") {
                                        QGroundControl.showMessageDialog(firmwarePage, firmwareSelectDialog.title, qsTr("Для выбранного прошивка не найдена."))
                                        firmwareSelectDialog.preventClose = true
                                        return
                                    }
                                    controller.flashFirmwareUrl(controller.apmFirmwareUrls[ardupilotFirmwareSelectionCombo.currentIndex])
                                    return
                                }
                            }
                            //-- If custom, get file path
                            if (firmwareBuildType === FirmwareUpgradeController.CustomFirmware) {
                                customFirmwareDialog.openForLoad()
                            } else {
                                controller.flash(stack, firmwareBuildType, vehicleType)
                            }
                        }
                    }

                    function reject() {
                        statusTextArea.append(highlightPrefix + qsTr("Обновление отменено") + highlightSuffix)
                        controller.cancel()
                        close()
                    }

                    ListModel {
                        id: firmwareBuildTypeList

                        ListElement {
                            text:           qsTr("Стабильная версия (stable)")
                            firmwareType:   FirmwareUpgradeController.StableFirmware
                        }
                        ListElement {
                            text:           qsTr("Бета-версия (beta)")
                            firmwareType:   FirmwareUpgradeController.BetaFirmware
                        }
                        ListElement {
                            text:           qsTr("Сборка разработчиков (master)")
                            firmwareType:   FirmwareUpgradeController.DeveloperFirmware
                        }
                        ListElement {
                            text:           qsTr("Свой файл прошивки...")
                            firmwareType:   FirmwareUpgradeController.CustomFirmware
                        }
                    }

                    ListModel {
                        id: singleFirmwareModeTypeList

                        ListElement {
                            text:           qsTr("Стабильная версия")
                            firmwareType:   FirmwareUpgradeController.StableFirmware
                        }
                        ListElement {
                            text:           qsTr("Свой файл прошивки...")
                            firmwareType:   FirmwareUpgradeController.CustomFirmware
                        }
                    }

                    ColumnLayout {
                        width:      Math.max(ScreenTools.defaultFontPixelWidth * 40, firmwareRadiosColumn.width)
                        spacing:    globals.defaultTextHeight / 2

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               (_singleFirmwareMode || !QGroundControl.apmFirmwareSupported) ? _singleFirmwareLabel : _pixhawkLabel

                            readonly property string _pixhawkLabel:          qsTr("Найдена плата Pixhawk. Выберите прошивку:")
                            readonly property string _singleFirmwareLabel:   qsTr("Нажмите OK, чтобы обновить прошивку.")
                        }

                        Column {
                            id:         firmwareRadiosColumn
                            spacing:    0

                            visible: !_singleFirmwareMode && QGroundControl.apmFirmwareSupported

                            Component.onCompleted: {
                                if(!QGroundControl.apmFirmwareSupported) {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypePX4
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }

                            QGCRadioButton {
                                id:             px4FlightStackRadio
                                text:           qsTr("PX4 Pro ")
                                font.bold:      _defaultFirmwareIsPX4
                                checked:        _defaultFirmwareIsPX4

                                onClicked: {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypePX4
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }

                            QGCRadioButton {
                                id:             apmFlightStack
                                text:           qsTr("ArduPilot")
                                font.bold:      !_defaultFirmwareIsPX4
                                checked:        !_defaultFirmwareIsPX4

                                onClicked: {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypeAPM
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }
                        }

                        FactComboBox {
                            Layout.fillWidth:   true
                            visible:            apmFlightStack.checked
                            fact:               _firmwareUpgradeSettings.apmChibiOS
                            indexModel:         false
                        }

                        FactComboBox {
                            id:                 apmVehicleTypeCombo
                            Layout.fillWidth:   true
                            visible:            apmFlightStack.checked
                            fact:               _firmwareUpgradeSettings.apmVehicleType
                            indexModel:         false
                        }

                        QGCComboBox {
                            id:                 ardupilotFirmwareSelectionCombo
                            Layout.fillWidth:   true
                            visible:            apmFlightStack.checked && !controller.downloadingFirmwareList && controller.apmFirmwareNames.length !== 0
                            model:              controller.apmFirmwareNames
                            onModelChanged:     currentIndex = controller.apmFirmwareNamesBestIndex
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("Загрузка списка прошивок...")
                            visible:            controller.downloadingFirmwareList
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("Нет доступных прошивок")
                            visible:            !controller.downloadingFirmwareList && (QGroundControl.apmFirmwareSupported && controller.apmFirmwareNames.length === 0)
                        }

                        QGCCheckBox {
                            id:         _advanced
                            text:       qsTr("Дополнительные настройки")
                            checked:    false

                            onClicked: {
                                firmwareBuildTypeCombo.currentIndex = 0
                                firmwareWarningMessageVisible = false
                                updatePX4VersionDisplay()
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            visible:            showFirmwareTypeSelection
                            text:               _singleFirmwareMode ?  qsTr("Выберите стабильную версию или файл на диске (скачанный ранее):") :
                                                                      qsTr("Выберите версию прошивки для установки:")
                        }

                        QGCComboBox {
                            id:                 firmwareBuildTypeCombo
                            Layout.fillWidth:   true
                            visible:            showFirmwareTypeSelection
                            textRole:           "text"
                            model:              _singleFirmwareMode ? singleFirmwareModeTypeList : firmwareBuildTypeList

                            onActivated: (index) => {
                                var fwType = model.get(index).firmwareType
                                controller.selectedFirmwareBuildType = fwType
                                if (fwType === FirmwareUpgradeController.BetaFirmware) {
                                    firmwareWarningMessageVisible = true
                                    firmwareVersionWarningLabel.text = qsTr("ВНИМАНИЕ: БЕТА-ПРОШИВКА. ") +
                                            qsTr("Эта версия предназначена ТОЛЬКО для тестировщиков. ") +
                                            qsTr("Хотя она прошла испытания, код активно меняется. ") +
                                            qsTr("НЕ используйте её в обычной работе.")
                                } else if (fwType === FirmwareUpgradeController.DeveloperFirmware) {
                                    firmwareWarningMessageVisible = true
                                    firmwareVersionWarningLabel.text = qsTr("ВНИМАНИЕ: НЕСТАБИЛЬНАЯ СБОРКА. ") +
                                            qsTr("Эта прошивка НЕ ИСПЫТАНА. ") +
                                            qsTr("Она только для РАЗРАБОТЧИКОВ. ") +
                                            qsTr("Сначала проверьте на стенде без винтов. ") +
                                            qsTr("НЕ используйте без дополнительных мер безопасности. ") +
                                            qsTr("Следите за форумами при её использовании.")
                                } else {
                                    firmwareWarningMessageVisible = false
                                }
                                updatePX4VersionDisplay()
                                if (fwType === FirmwareUpgradeController.CustomFirmware) {
                                    customFirmwareDialog.openForLoad()
                                }
                            }
                        }

                        QGCLabel {
                            id:                 firmwareVersionWarningLabel
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            visible:            firmwareWarningMessageVisible
                        }
                    } // ColumnLayout
                } // QGCPopupDialog
            } // Component - firmwareSelectDialogComponent

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                visible: !flashBootloaderButton.visible

                QGCComboBox {
                    id:                 portCombo
                    sizeToContents:     true
                    visible:            !_flashStarted
                    enabled:            controller.availablePorts.length > 0
                    model:              controller.availablePorts
                    textRole:           "displayName"

                    alternateText: {
                        if (_lastKnownCount !== 1) {
                            return ""
                        }
                        var idx = portCombo.currentIndex
                        var ports = controller.availablePorts
                        if (idx < 0 || idx >= ports.length) {
                            return ""
                        }
                        var p = ports[idx]
                        if (p.boardName && p.description) {
                            return p.description + " [" + p.boardName + "]"
                        }
                        return p.boardName || p.description || p.displayName
                    }

                    onActivated: (index) => {
                        if (index >= 0 && index < controller.availablePorts.length) {
                            _selectedSystemLocation = controller.availablePorts[index].systemLocation
                        }
                    }
                }

                QGCLabel {
                    id:         portLabel
                    visible:    _flashStarted
                    text:       qsTr("Прошивка — %1").arg(_selectedDisplayName)
                    elide:      Text.ElideRight
                }

                QGCButton {
                    id:         flashButton
                    text:       qsTr("Прошить")
                    visible:    !_flashStarted
                    enabled:    portCombo.currentIndex >= 0 && controller.availablePorts.length > 0
                    onClicked: {
                        var ports = controller.availablePorts
                        if (portCombo.currentIndex < 0 || portCombo.currentIndex >= ports.length) {
                            return
                        }
                        var entry = ports[portCombo.currentIndex]
                        _selectedSystemLocation = entry.systemLocation
                        _selectedDisplayName = portCombo.alternateText !== "" ? portCombo.alternateText : entry.displayName
                        _flashStarted = true
                        statusTextArea.append(unplugReplugText)
                        if (QGroundControl.multiVehicleManager.activeVehicle) {
                            QGroundControl.multiVehicleManager.activeVehicle.vehicleLinkManager.autoDisconnect = true
                        }
                        controller.flashPort(entry.systemLocation)
                    }
                }

                QGCButton {
                    id:         cancelButton
                    text:       qsTr("Отмена")
                    visible:    _flashStarted
                    enabled:    _cancellable
                    onClicked: {
                        controller.cancel()
                        _flashStarted = false
                        _cancellable = true
                        _selectedDisplayName = ""
                        statusTextArea.append(highlightPrefix + qsTr("Отменено. Выберите порт и нажмите «Прошить» ещё раз.") + highlightSuffix)
                    }
                }
            }

            ProgressBar {
                id:                     progressBar
                Layout.preferredWidth:  parent.width
                visible:                !flashBootloaderButton.visible
            }

            QGCButton {
                id:         flashBootloaderButton
                text:       qsTr("Прошить загрузчик ChibiOS")
                visible:    firmwarePage.advanced
                onClicked:  globals.activeVehicle.flashBootloader()
            }

            TextArea {
                id:                 statusTextArea
                Layout.preferredWidth:              parent.width
                Layout.fillHeight:  true
                readOnly:           true
                font.pointSize:     ScreenTools.defaultFontPointSize
                textFormat:         TextEdit.RichText
                text:               _singleFirmwareMode ? welcomeTextSingle : welcomeText
                color:              qgcPal.text

                background: Rectangle {
                    color: qgcPal.windowShade
                }
            }

        } // ColumnLayout
    } // Component
} // SetupPage
