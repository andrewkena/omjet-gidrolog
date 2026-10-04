import QtQuick

import QGroundControl
import QGroundControl.Controls

SelectableControl {
    id:                     instrumentPanelRoot
    z:                      QGroundControl.zOrderWidgets
    selectionUIRightAnchor: true
    allowSelection:         false   // GidroLog: fixed pitch / roll / compass block, no variant selector
    selectedControl:        QGroundControl.settingsManager.flyViewSettings.instrumentQmlFile2

    property var  missionController:    _missionController
    property real extraInset:           innerControl.extraInset
    property real extraValuesWidth:     innerControl.extraValuesWidth

    // GidroLog: vehicle messages popup is placed above this panel (see MainWindow criticalVehicleMessagePopup)
    Component.onCompleted: mainWindow.gidroLogInstrumentPanel = instrumentPanelRoot
}
