import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Toolbar for Plan View
RowLayout {
    required property var planMasterController
    property bool showRallyPointsHelp: false

    signal toolbarButtonClicked()

    id: root
    spacing: ScreenTools.defaultFontPixelWidth

    property var _planMasterController: planMasterController
    property var _missionController: _planMasterController.missionController
    property var _geoFenceController: _planMasterController.geoFenceController
    property var _rallyPointController: _planMasterController.rallyPointController
    property bool _controllerOffline: _planMasterController.offline
    property var _saveDirty: _planMasterController.dirtyForSave
    property var _uploadDirty: _planMasterController.dirtyForUpload
    property var _syncInProgress: _planMasterController.syncInProgress
    property var _visualItems: _missionController.visualItems
    property bool _hasPlanItems: _planMasterController.containsItems

    readonly property real _margins: ScreenTools.defaultFontPixelWidth

    function _uploadClicked() {
        _planMasterController.upload()
    }

    function _downloadClicked() {
        if (_saveDirty) {
            QGroundControl.showMessageDialog(root, qsTr("Скачать"),
                                         qsTr("Есть несохранённые изменения. При скачивании с борта они пропадут. Продолжить?"),
                                         Dialog.Yes | Dialog.Cancel,
                                         function() { _planMasterController.loadFromVehicle() })
        } else {
            _planMasterController.loadFromVehicle()
        }
    }

    function _openButtonClicked() {
        // Unsent changes don't matter when offline or when the plan is safely saved to a file
        let planSafeOnDisk = !_saveDirty && _planMasterController.currentPlanFile !== ""
        let unsentChanges = _uploadDirty && !_controllerOffline && !planSafeOnDisk
        if (_saveDirty || unsentChanges) {
            let msg
            if (_saveDirty && unsentChanges) {
                msg = qsTr("Есть несохранённые и не загруженные на борт изменения. При открытии нового задания они пропадут. Продолжить?")
            } else if (_saveDirty) {
                msg = qsTr("Есть несохранённые изменения. При открытии нового задания они пропадут. Продолжить?")
            } else {
                msg = qsTr("Есть не загруженные на борт изменения. При открытии нового задания они пропадут. Продолжить?")
            }
            QGroundControl.showMessageDialog(root, qsTr("Открыть задание"),
                                        msg,
                                        Dialog.Yes | Dialog.Cancel,
                                        function() { _planMasterController.loadFromSelectedFile() } )
        } else {
            _planMasterController.loadFromSelectedFile()
        }
    }

    function _saveButtonClicked() {
        if (_planMasterController.currentPlanFile === "") {
            _planMasterController.saveToSelectedFile()
        } else {
            _planMasterController.saveToCurrent()
        }
    }

    function _saveAsKMLClicked() {
        // Don't save if we only have Mission Settings item
        if (_visualItems.count > 1) {
            _planMasterController.saveKmlToSelectedFile()
        }
    }

    function _storageClearButtonClicked() {
        QGroundControl.showMessageDialog(root, qsTr("Очистить"),
                                     qsTr("Удалить все точки из редактора задания?"),
                                     Dialog.Yes | Dialog.Cancel,
                                     function() { _planMasterController.removeAll(); })
    }

    function _vehicleClearButtonClicked() {
        QGroundControl.showMessageDialog(root, qsTr("Очистить"),
                                     qsTr("Удалить задание с борта и из редактора?"),
                                     Dialog.Yes | Dialog.Cancel,
                                     function() {
                                        _planMasterController.removeAllFromVehicle()
                                     })
    }

    function _clearClicked() {
        if (_planMasterController.offline) {
            _storageClearButtonClicked();
        } else {
            _vehicleClearButtonClicked();
        }
    }

    QGCPalette { id: qgcPal }

    QGCButton {
        objectName: "planToolbar_openButton"
        text: qsTr("Открыть")
        iconSource: "/qmlimages/Plan.svg"
        enabled: !_planMasterController.syncInProgress
        onClicked: { toolbarButtonClicked(); _openButtonClicked() }
    }

    QGCButton {
        objectName: "planToolbar_saveButton"
        text: qsTr("Сохранить")
        iconSource: "/res/SaveToDisk.svg"
        enabled: !_syncInProgress && _hasPlanItems
        primary: _saveDirty
        onClicked: { toolbarButtonClicked(); _saveButtonClicked() }
    }

    QGCButton {
        id: uploadButton
        objectName: "planToolbar_uploadButton"
        text: qsTr("Загрузить на борт")
        iconSource: "/res/UploadToVehicle.svg"
        enabled: !_syncInProgress && _hasPlanItems && !_controllerOffline
        visible: !_syncInProgress
        primary: _uploadDirty && !_controllerOffline
        onClicked: { toolbarButtonClicked(); _uploadClicked() }
    }

    // GidroLog: download moved from the hamburger menu next to Upload
    QGCButton {
        objectName: "planToolbar_downloadButton"
        text: qsTr("Скачать с борта")
        iconSource: "/res/Download.svg"
        enabled: !_syncInProgress && !_controllerOffline
        visible: !_syncInProgress
        onClicked: { toolbarButtonClicked(); _downloadClicked() }
    }

    QGCButton {
        objectName: "planToolbar_clearButton"
        text: qsTr("Очистить")
        iconSource: "/res/TrashCan.svg"
        enabled: !_syncInProgress
        onClicked: { toolbarButtonClicked(); _clearClicked() }
    }

    QGCButton {
        objectName: "planToolbar_hamburgerButton"
        iconSource: "qrc:/qmlimages/Hamburger.svg"

        onClicked: {
            let position = Qt.point(width, height / 2)
            // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
            position = mapToItem(globals.parent, position)
            var dropPanel = hamburgerDropPanelComponent.createObject(mainWindow, { clickRect: Qt.rect(position.x, position.y, 0, 0) })
            dropPanel.open()
        }
    }

    QGCLabel {
        text:    qsTr("Нажмите на карту, чтобы добавить точки сбора")
        visible: root.showRallyPointsHelp
        Layout.alignment: Qt.AlignVCenter
    }

    Component {
        id: hamburgerDropPanelComponent

        DropPanel {
            id: dropPanel

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 2

                    QGCButton {
                        objectName: "planToolbar_saveAsButton"
                        Layout.fillWidth: true
                        text: qsTr("Сохранить как...")
                        enabled: !_syncInProgress && _hasPlanItems

                        onClicked: {
                            dropPanel.close()
                            _planMasterController.saveToSelectedFile()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Сохранить KML")
                        enabled: !_syncInProgress && _hasPlanItems

                        onClicked: {
                            dropPanel.close()
                            _saveAsKMLClicked()
                        }
                    }
                }
            }
        }
    }
}
