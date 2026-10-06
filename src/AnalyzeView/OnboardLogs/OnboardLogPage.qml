import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AnalyzePage {
    id: onboardLogPage
    pageComponent: pageComponent
    pageDescription: qsTr("Здесь можно скачать логи с борта. Нажмите «Обновить», чтобы получить список.")

    function _updateNavigationBlocked() {
        if (OnboardLogController.downloadingLogs) {
            globals.navigationBlockedReason = qsTr("Дождитесь окончания скачивания лога или отмените его")
        } else {
            globals.navigationBlockedReason = ""
        }
    }

    Connections {
        target: OnboardLogController
        function onDownloadingLogsChanged() { onboardLogPage._updateNavigationBlocked() }
    }

    Component.onCompleted: _updateNavigationBlocked()
    Component.onDestruction: globals.navigationBlockedReason = ""

    Component {
        id: pageComponent

        RowLayout {
            width: availableWidth
            height: availableHeight

            Component.onCompleted: OnboardLogController.refresh()

            QGCFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: gridLayout.width
                contentHeight: gridLayout.height

                GridLayout {
                    id: gridLayout
                    rows: OnboardLogController.model.count + 1
                    columns: 5
                    flow: GridLayout.TopToBottom
                    columnSpacing: ScreenTools.defaultFontPixelWidth
                    rowSpacing: 0

                    Item { } // First column is for checkboxes, so add empty item to align headers with log entries

                    Repeater {
                        model: OnboardLogController.model

                        QGCCheckBox {
                            objectName: "onboardLogCheckbox_" + index

                            Binding on checkState {
                                value: object.selected ? Qt.Checked : Qt.Unchecked
                            }

                            onClicked: object.selected = checked
                        }
                    }

                    QGCLabel { text: qsTr("№") }

                    Repeater {
                        model: OnboardLogController.model

                        QGCLabel { text: object.id }
                    }

                    QGCLabel { text: qsTr("Дата") }

                    Repeater {
                        model: OnboardLogController.model

                        QGCLabel {
                            objectName: "onboardLogDate_" + index

                            text: {
                                if (!object.received) {
                                    return ""
                                }

                                // getUTCFullYear() is NaN for an invalid date
                                const year = object.time.getUTCFullYear()
                                if (Number.isNaN(year) || year < 2010) {
                                    return qsTr("Дата неизвестна")
                                }

                                return object.time.toLocaleString(undefined)
                            }
                        }
                    }

                    QGCLabel { text: qsTr("Размер") }

                    Repeater {
                        model: OnboardLogController.model

                        QGCLabel { text: object.sizeStr }
                    }

                    QGCLabel { text: qsTr("Статус") }

                    Repeater {
                        model: OnboardLogController.model

                        QGCLabel {
                            objectName: "onboardLogStatus_" + index
                            text: object.status
                        }
                    }
                }
            }

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: false

                QGCButton {
                    objectName: "onboardLog_refreshButton"
                    Layout.fillWidth: true
                    enabled: !OnboardLogController.requestingList && !OnboardLogController.downloadingLogs
                    text: qsTr("Обновить")

                    onClicked: {
                        if (!QGroundControl.multiVehicleManager.activeVehicle || QGroundControl.multiVehicleManager.activeVehicle.isOfflineEditingVehicle) {
                            QGroundControl.showMessageDialog(onboardLogPage, qsTr("Обновление списка логов"), qsTr("Чтобы скачать логи с борта, подключитесь к нему."))
                            return
                        }

                        OnboardLogController.refresh()
                    }
                }

                QGCButton {
                    objectName: "onboardLog_selectAllButton"
                    Layout.fillWidth: true
                    enabled: !OnboardLogController.requestingList && !OnboardLogController.downloadingLogs && (OnboardLogController.model.count > 0)
                    text: OnboardLogController.allLogsSelected ? qsTr("Снять всё") : qsTr("Выбрать всё")
                    onClicked: OnboardLogController.selectAll(!OnboardLogController.allLogsSelected)
                }

                QGCButton {
                    objectName: "onboardLog_downloadButton"
                    Layout.fillWidth: true
                    enabled: !OnboardLogController.requestingList && !OnboardLogController.downloadingLogs && (OnboardLogController.selectedCount > 0)
                    text: qsTr("Скачать")

                    onClicked: {
                        if (ScreenTools.isMobile) {
                            OnboardLogController.download()
                            return
                        }

                        fileDialog.title = qsTr("Выберите папку для сохранения")
                        fileDialog.folder = QGroundControl.settingsManager.appSettings.logSavePath
                        fileDialog.selectFolder = true
                        fileDialog.openForLoad()
                    }

                    QGCFileDialog {
                        id: fileDialog
                        onAcceptedForLoad: (file) => {
                            OnboardLogController.download(file)
                            close()
                        }
                    }
                }

                QGCButton {
                    objectName: "onboardLog_sortButton"
                    Layout.fillWidth: true
                    enabled: !OnboardLogController.requestingList && !OnboardLogController.downloadingLogs && (OnboardLogController.model.count > 1)
                    text: OnboardLogController.sortAscending ? qsTr("По убыванию") : qsTr("По возрастанию")
                    onClicked: OnboardLogController.toggleSortByDate()
                }

                QGCButton {
                    objectName: "onboardLog_eraseSelectedButton"
                    Layout.fillWidth: true
                    visible: OnboardLogController.transport === "ftp"
                    enabled: !OnboardLogController.requestingList && !OnboardLogController.downloadingLogs && (OnboardLogController.selectedCount > 0)
                    text: qsTr("Стереть выбранные")
                    onClicked: QGroundControl.showMessageDialog(
                        onboardLogPage,
                        qsTr("Удалить выбранные логи на борту"),
                        qsTr("Выбранные логи на борту будут удалены безвозвратно. Продолжить?"),
                        Dialog.Yes | Dialog.No,
                        function() { OnboardLogController.eraseSelected() }
                    )
                }

                QGCButton {
                    objectName: "onboardLog_eraseAllButton"
                    Layout.fillWidth: true
                    enabled: !OnboardLogController.requestingList && !OnboardLogController.downloadingLogs && (OnboardLogController.model.count > 0)
                    text: qsTr("Стереть все")
                    onClicked: QGroundControl.showMessageDialog(
                        onboardLogPage,
                        qsTr("Удалить все логи на борту"),
                        qsTr("Все логи на борту будут удалены безвозвратно. Продолжить?"),
                        Dialog.Yes | Dialog.No,
                        function() { OnboardLogController.eraseAll() }
                    )
                }

                QGCButton {
                    objectName: "onboardLog_cancelButton"
                    Layout.fillWidth: true
                    text: qsTr("Отмена")
                    enabled: OnboardLogController.requestingList || OnboardLogController.downloadingLogs
                    onClicked: OnboardLogController.cancel()
                }
            }
        }
    }
}
