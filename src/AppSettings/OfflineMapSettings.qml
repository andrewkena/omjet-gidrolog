import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.QGCMapEngineManager

/// Offline map tile set management: list, add, import, export, and progress display.
/// Self-contained component including all dialogs needed for offline map operations.
Item {
    id: root
    implicitHeight: mainLayout.implicitHeight

    property var _mapEngineManager: QGroundControl.mapEngineManager
    property var _appSettings:      QGroundControl.settingsManager.appSettings
    property bool _currentlyImportOrExporting: _mapEngineManager.importAction === QGCMapEngineManager.ImportAction.ActionExporting ||
                                               _mapEngineManager.importAction === QGCMapEngineManager.ImportAction.ActionImporting

    Component.onCompleted: _mapEngineManager.loadTileSets()

    Connections {
        target:                 _mapEngineManager
        function onErrorMessageChanged() { errorDialogFactory.open() }
    }

    ColumnLayout {
        id:    mainLayout
        width: parent.width

        SettingsGroupLayout {
            Layout.fillWidth:   true
            heading:            qsTr("Офлайн-карты")
            headingDescription: qsTr("Скачайте тайлы карты для работы без интернета")

            Repeater {
                model: _mapEngineManager.tileSets

                OfflineMapInfo {
                    tileSet:    object
                    enabled:    !object.deleting
                    onClicked:  offlineMapEditorComponent.createObject(mainWindow.contentItem, { tileSet: object }).showInfo()
                }
            }

            LabelledButton {
                label:      qsTr("Новый набор")
                buttonText: qsTr("Добавить")
                enabled:    !_currentlyImportOrExporting
                onClicked:  offlineMapEditorComponent.createObject(mainWindow.contentItem).addNewSet()
            }

            LabelledButton {
                label:      qsTr("Импорт тайлов")
                buttonText: qsTr("Импорт")
                visible:    QGroundControl.corePlugin.options.showOfflineMapImport
                enabled:    !_currentlyImportOrExporting
                onClicked: {
                    _mapEngineManager.importAction = QGCMapEngineManager.ImportAction.ActionNone
                    importDialogFactory.open()
                }
            }

            LabelledButton {
                label:      qsTr("Экспорт тайлов")
                buttonText: qsTr("Экспорт")
                visible:    QGroundControl.corePlugin.options.showOfflineMapExport
                enabled:    !_currentlyImportOrExporting
                onClicked:  exportDialogFactory.open()
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                visible: _currentlyImportOrExporting

                QGCLabel {
                    Layout.fillWidth:   true
                    text:               _mapEngineManager.importAction === QGCMapEngineManager.ImportAction.ActionExporting ? qsTr("Экспорт...") : qsTr("Импорт...")
                    font.bold:          true
                }
                ProgressBar {
                    width:  ScreenTools.defaultFontPixelWidth * 25
                    from:   0
                    to:     100
                    value:  _mapEngineManager.actionProgress
                }
            }
        }
    }

    QGCFileDialog {
        id:             fileDialog
        folder:         _appSettings.missionSavePath
        nameFilters:    [ qsTr("Наборы тайлов (*.%1)").arg(defaultSuffix) ]
        defaultSuffix:  _appSettings.tilesetFileExtension

        onAcceptedForSave: (file) => {
            close()
            _mapEngineManager.exportSets(file)
        }

        onAcceptedForLoad: (file) => {
            close()
            _mapEngineManager.importSets(file)
        }
    }

    QGCPopupDialogFactory {
        id: exportDialogFactory
        dialogComponent: exportDialogComponent
    }

    Component {
        id: exportDialogComponent

        QGCPopupDialog {
            title:      qsTr("Экспорт выбранных наборов")
            buttons:    Dialog.Ok | Dialog.Cancel

            onAccepted: {
                close()
                fileDialog.title = qsTr("Экспорт тайлов")
                fileDialog.openForSave()
            }

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelWidth / 2

                Repeater {
                    model: _mapEngineManager.tileSets

                    QGCCheckBox {
                        text:       object.name
                        checked:    object.selected
                        onClicked:  object.selected = checked
                    }
                }
            }
        }
    }

    QGCPopupDialogFactory {
        id: importDialogFactory
        dialogComponent: importDialogComponent
    }

    Component {
        id: importDialogComponent

        QGCPopupDialog {
            title:      qsTr("Импорт наборов")
            buttons:    Dialog.Ok | Dialog.Cancel

            onAccepted: {
                close()
                fileDialog.title = qsTr("Импорт тайлов")
                fileDialog.openForLoad()
            }

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelWidth / 2

                QGCRadioButton {
                    text:       qsTr("Добавить к существующим")
                    checked:    !_mapEngineManager.importReplace
                    onClicked:  _mapEngineManager.importReplace = !checked
                }
                QGCRadioButton {
                    text:       qsTr("Заменить существующие")
                    checked:    _mapEngineManager.importReplace
                    onClicked:  _mapEngineManager.importReplace = checked
                }
            }
        }
    }

    QGCPopupDialogFactory {
        id: errorDialogFactory
        dialogComponent: errorDialogComponent
    }

    Component {
        id: errorDialogComponent

        QGCSimpleMessageDialog {
            title:      qsTr("Ошибка")
            text:       _mapEngineManager.errorMessage
            buttons:    Dialog.Close
        }
    }

    Component {
        id: offlineMapEditorComponent

        OfflineMapEditor {
            id:             offlineMapEditor
            anchors.fill:   parent
            z:              QGroundControl.zOrderTopMost
        }
    }
}
