import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.PlanView
import QGroundControl.Toolbar

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:         mainWindow

    // GidroLog: app-wide settings shared by the settings page and the Fly View panels
    property alias gidroLogSettings: _gidroLogSettings

    Settings {
        id:         _gidroLogSettings
        category:   "GidroLogControl"

        property int sirenChannel:      0       // RC channel 1..16, 0 = not assigned
        property int sirenThreshold:    1700    // PWM (us) at/above which the siren is on
        property int beaconChannel:     0
        property int beaconThreshold:   1700
    }
    visible:    true
    title:      "ОМДЖЕТ ГидроЛог " + Qt.application.version.replace(/^v/, "") + "_" + Qt.formatDate(new Date(), "dd.MM.yyyy")  // GidroLog: window title
    // The special casing for android prevents white bars from showing up on the edges of the screen with newer android versions
    flags:      Qt.Window | (ScreenTools.isAndroid ? Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint : 0)

    // Qt 6.9+ auto-sets ApplicationWindow padding to the display safe-area insets on mobile,
    // which insets our full-bleed content and leaves a blank strip along the screen edge.
    // QGC draws edge-to-edge and manages its own insets, so zero the padding.
    topPadding:    0
    bottomPadding: 0
    leftPadding:   0
    rightPadding:  0

    Component.onCompleted: {
        // Start the sequence of first run prompt(s)
        firstRunPromptManager.nextPrompt()
    }

    /// Saves main window position and size and re-opens it in the same position and size next time
    MainWindowSavedState {
        window: mainWindow
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       QGroundControl.corePlugin.firstRunPromptsToShow()
        property int nextPromptIdIndex: 0

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow)
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    flyView.planController
        readonly property var       guidedControllerFlyView:        flyView.guidedController

        // Number of QGCTextField's with validation errors. Used to prevent closing panels with validation errors.
        property int                validationErrorCount:           0

        // Set to a non-empty string to block navigation with a custom reason (e.g. during calibration)
        property string             navigationBlockedReason:        ""

        // Property to manage RemoteID quick access to settings page
        property bool               commingFromRIDIndicator:        false
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    // This function is used to prevent view switching if there are validation errors
    function allowViewSwitch(previousValidationErrorCount = 0, showErrorOnDisallow = true) {
        // Check for explicit navigation block (e.g. calibration in progress)
        if (globals.navigationBlockedReason !== "") {
            if (showErrorOnDisallow) {
                validationErrorToast.text = globals.navigationBlockedReason
                if (validationErrorToast.visible) {
                    validationErrorToast.close()
                }
                validationErrorToast.open()
            }
            return false
        }
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished()
        }
        var allowed = globals.validationErrorCount <= previousValidationErrorCount
        if (!allowed && showErrorOnDisallow) {
            validationErrorToast.text = qsTr("Please correct the invalid value before continuing")
            if (validationErrorToast.visible) {
                validationErrorToast.close()
            }
            validationErrorToast.open()
        }
        return allowed
    }

    function showPlanView() {
        flyView.visible = false
        planView.visible = true
        toolDrawer.visible = false
    }

    function showFlyView() {
        flyView.visible = true
        planView.visible = false
        toolDrawer.visible = false
    }

    function showTool(toolTitle, toolSource, toolIcon) {
        toolDrawer.backIcon     = flyView.visible ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Plan.svg"
        toolDrawer.toolTitle    = toolTitle
        toolDrawer.toolSource   = toolSource
        toolDrawer.toolIcon     = toolIcon
        toolDrawer.visible      = true
    }

    function showAnalyzeTool() {
        showTool(qsTr("АНАЛИЗ"), "qrc:/qml/QGroundControl/AnalyzeView/AnalyzeView.qml", "/qmlimages/Analyze.svg")
    }

    function showVehicleConfig() {
        showTool(qsTr("ПАРАМЕТРЫ СУДНА"), "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml", "/qmlimages/Gears.svg")
    }

    function showVehicleConfigParametersPage() {
        showVehicleConfig()
        toolDrawerLoader.item.showParametersPanel()
    }

    function showKnownVehicleComponentConfigPage(knownVehicleComponent) {
        showVehicleConfig()
        let vehicleComponent = globals.activeVehicle.autopilotPlugin.findKnownVehicleComponent(knownVehicleComponent)
        if (vehicleComponent) {
            toolDrawerLoader.item.showVehicleComponentPanel(vehicleComponent)
        }
    }

    function showSettingsTool(settingsPage = "") {
        showTool(qsTr("НАСТРОЙКИ ПРОГРАММЫ"), "qrc:/qml/QGroundControl/Controls/AppSettings.qml", "/res/QGCLogoWhite")
        if (settingsPage !== "") {
            toolDrawerLoader.item.showSettingsPage(settingsPage)
        }
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function _showMessageDialogWorker(owner, dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null, bypassNavigationCheck = false) {
        let dialog = simpleMessageDialogComponent.createObject(owner, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction, closeFunction: closeFunction, bypassNavigationCheck: bypassNavigationCheck })
        dialog.open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle, dialogText)
    }

    // This variant is only meant to be called by QGCApplication. Ok reboots the active vehicle.
    function _showRebootVehicleDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle,
                                 dialogText + " " + qsTr("Click Ok to reboot the vehicle now."),
                                 Dialog.Ok | Dialog.Cancel,
                                 function() {
                                     const activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                                     if (activeVehicle) {
                                         activeVehicle.rebootVehicle()
                                     }
                                 })
    }

    Connections {
        target: QGroundControl

        function onShowMessageDialogRequested(owner, title, text, buttons, acceptFunction, closeFunction) {
            _showMessageDialogWorker(owner, title, text, buttons, acceptFunction, closeFunction)
        }
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    property bool _forceClose: false
    property bool suppressCriticalVehicleMessages: false
    property var  gidroLogInstrumentPanel:          null    // GidroLog: set by FlyViewInstrumentPanel

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // Check for things which should prevent the app from closing
    //  Returns true if it is OK to close
    readonly property int _skipUnsavedMissionCheckMask: 0x01
    readonly property int _skipPendingParameterWritesCheckMask: 0x02
    readonly property int _skipActiveConnectionsCheckMask: 0x04
    property int _closeChecksToSkip: 0
    property bool _reentrantCloseGuard: false
    function performCloseChecks() {
        if (!(_closeChecksToSkip & _skipUnsavedMissionCheckMask) && !checkForUnsavedMission()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipPendingParameterWritesCheckMask) && !checkForPendingParameterWrites()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipActiveConnectionsCheckMask) && !checkForActiveConnections()) {
            return false
        }
        finishCloseProcess()
        return true
    }

    function checkForUnsavedMission() {
        // Only warn when edits are neither saved to disk nor uploaded to the vehicle.
        // If either happened the edits are recoverable, so closing loses nothing.
        // With no active vehicle an upload can't have happened, so treat the plan as
        // not uploaded regardless of dirtyForUpload.
        if (planView._planMasterController.dirtyForSave &&
                (planView._planMasterController.dirtyForUpload || !QGroundControl.multiVehicleManager.activeVehicle)) {
            let accepted = false
            _reentrantCloseGuard = true
            _showMessageDialogWorker(mainWindow, qsTr("Unsaved Mission"),
                              qsTr("You have a mission edit in progress which has not been saved/uploaded. If you close you will lose changes. Are you sure you want to close?"),
                              Dialog.Yes | Dialog.No,
                              function() { accepted = true; _closeChecksToSkip |= _skipUnsavedMissionCheckMask; performCloseChecks() },
                              function() { if (!accepted) _reentrantCloseGuard = false },
                              true /* bypassNavigationCheck */)
            return false
        } else {
            return true
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                let accepted = false
                _reentrantCloseGuard = true
                _showMessageDialogWorker(mainWindow, qsTr("Pending Parameter Updates"),
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                    Dialog.Yes | Dialog.No,
                    function() { accepted = true; _closeChecksToSkip |= _skipPendingParameterWritesCheckMask; performCloseChecks() },
                    function() { if (!accepted) _reentrantCloseGuard = false },
                    true /* bypassNavigationCheck */)
                return false
            }
        }
        return true
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            let accepted = false
            _reentrantCloseGuard = true
            _showMessageDialogWorker(mainWindow, qsTr("Active Vehicle Connections"),
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                Dialog.Yes | Dialog.No,
                function() { accepted = true; _closeChecksToSkip |= _skipActiveConnectionsCheckMask; performCloseChecks() },
                function() { if (!accepted) _reentrantCloseGuard = false },
                true /* bypassNavigationCheck */)
            return false
        } else {
            return true
        }
    }

    onClosing: (close) => {
        if (!_forceClose) {
            if (_reentrantCloseGuard) {
                close.accepted = false
                return
            }
            _closeChecksToSkip = 0
            close.accepted = performCloseChecks()
        }
    }

    background: Rectangle {
        anchors.fill:   parent
        color:          QGroundControl.globalPalette.window
    }

    FlyView {
        id:                     flyView
        objectName:             "mainView_fly"
        anchors.fill:           parent
    }

    PlanView {
        id:             planView
        objectName:     "mainView_plan"
        anchors.fill:   parent
        visible:        false
    }

    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    MessageDialog {
        id:                 showTouchAreasNotification
        title:              qsTr("Debug Touch Areas")
        text:               qsTr("Touch Area display toggled")
        buttons:            MessageDialog.Ok
    }

    MessageDialog {
        id:                 advancedModeOnConfirmation
        title:              qsTr("Advanced Mode")
        text:               QGroundControl.corePlugin.showAdvancedUIMessage
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = true
            }
        }
    }

    MessageDialog {
        id:                 advancedModeOffConfirmation
        title:              qsTr("Advanced Mode")
        text:               qsTr("Turn off Advanced Mode?")
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = false
            }
        }
    }

    function showToolSelectDialog() {
        if (mainWindow.allowViewSwitch()) {
            mainWindow.showIndicatorDrawer(toolSelectComponent, null)
        }
    }

    // Toast notification shown when a view switch is blocked by a validation error
    ToolTip {
        id:             validationErrorToast
        x:              (mainWindow.width - width) / 2
        y:              mainWindow.height - height - ScreenTools.defaultFontPixelHeight * 3
        timeout:        3000
        closePolicy:    Popup.NoAutoClose
        text:           qsTr("Please correct the invalid value before continuing")

        background: Rectangle {
            color:  qgcPal.alertBackground
            radius: ScreenTools.defaultFontPixelWidth / 2
        }

        contentItem: QGCLabel {
            text:   validationErrorToast.text
            color:  qgcPal.alertText
        }
    }

    Component {
        id: toolSelectComponent

        SelectViewDropdown {
        }
    }

    Rectangle {
        id:             toolDrawer
        objectName:     "mainView_toolDrawer"
        anchors.fill:   parent
        visible:        false
        color:          qgcPal.window

        property var backIcon
        property string toolTitle
        property alias toolSource:  toolDrawerLoader.source
        property var toolIcon

        onVisibleChanged: {
            if (!toolDrawer.visible) {
                toolDrawerLoader.source = ""
            }
        }

        // This need to block click event leakage to underlying map.
        DeadMouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id:             toolDrawerToolbar
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            height:         ScreenTools.toolbarHeight
            color:          qgcPal.toolbarBackground

            RowLayout {
                id:                 toolDrawerToolbarLayout
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                spacing:            ScreenTools.defaultFontPixelWidth

                QGCToolBarButton {
                    id: qgcButton
                    objectName: "toolbar_qgcLogo"
                    height: parent.height
                    icon.source: "/res/GidroLogIcon.png" // GidroLog
                    logo: true
                    onClicked: mainWindow.showToolSelectDialog()
                }

                QGCLabel {
                    id:             toolbarDrawerText
                    text:           toolDrawer.toolTitle
                    font.pointSize: ScreenTools.largeFontPointSize
                }
            }
        }

        Loader {
            id:             toolDrawerLoader
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    toolDrawerToolbar.bottom
            anchors.bottom: parent.bottom
        }
    }

    //-------------------------------------------------------------------------
    // GidroLog: Russian translation of autopilot / vehicle messages shown in the orange popup.
    // Exact phrases and patterns first, then common prefixes. Unknown text is left as is.
    readonly property var _gidroLogMessageRules: [
        // ---- Emergency stop / arming ----
        [ /Emergency Stop released/gi,                      "Аварийная остановка снята" ],
        [ /Emergency Stop/gi,                               "Аварийная остановка моторов" ],
        [ /Throttle armed/gi,                               "Моторы запущены" ],
        [ /Throttle disarmed/gi,                            "Моторы остановлены" ],
        [ /Arming motors/gi,                                "Запуск моторов" ],
        [ /Disarming motors/gi,                             "Остановка моторов" ],
        [ /Arming denied/gi,                                "Запуск запрещён" ],
        [ /Arm(ing)? failed/gi,                             "Запуск не удался" ],
        [ /Disarm(ing)? failed/gi,                          "Остановка не удалась" ],
        [ /Already armed/gi,                                "Уже запущен" ],
        [ /Motors: Check frame class and type/gi,           "Моторы: проверьте FRAME_CLASS и FRAME_TYPE" ],
        [ /Motor Emergency Stopped/gi,                      "Моторы аварийно остановлены" ],
        [ /Hardware safety switch/gi,                       "Аппаратный выключатель безопасности" ],
        [ /Safety switch/gi,                                "Выключатель безопасности" ],
        [ /Mode not armable/gi,                             "В этом режиме запуск невозможен" ],
        [ /Throttle \(RC(\d+)\) is not neutral/gi,          "Газ (RC$1) не в нейтрали" ],
        [ /Throttle not neutral/gi,                         "Газ не в нейтрали" ],
        [ /Crash: Disarming/gi,                             "Авария: моторы остановлены" ],
        [ /Crash: Going to HOLD/gi,                         "Авария: переход в HOLD" ],
        [ /Crash detected/gi,                               "Обнаружена авария" ],

        // ---- Sensors ----
        [ /Gyros not calibrated/gi,                         "Гироскопы не откалиброваны" ],
        [ /Gyros inconsistent/gi,                           "Гироскопы расходятся" ],
        [ /Gyros not healthy/gi,                            "Гироскопы неисправны" ],
        [ /Accels not calibrated/gi,                        "Акселерометры не откалиброваны" ],
        [ /Accels inconsistent/gi,                          "Акселерометры расходятся" ],
        [ /Accels not healthy/gi,                           "Акселерометры неисправны" ],
        [ /3D Accel calibration needed/gi,                  "Нужна калибровка акселерометров" ],
        [ /Compass not healthy/gi,                          "Компас неисправен" ],
        [ /Compass not calibrated/gi,                       "Компас не откалиброван" ],
        [ /Compass offsets too high/gi,                     "Слишком большие смещения компаса" ],
        [ /Compasses inconsistent/gi,                       "Компасы расходятся" ],
        [ /Check mag field/gi,                              "Проверьте магнитное поле" ],
        [ /Compass calibration running/gi,                  "Идёт калибровка компаса" ],
        [ /Baro not healthy/gi,                             "Барометр неисправен" ],
        [ /Barometer not healthy/gi,                        "Барометр неисправен" ],
        [ /INS not calibrated/gi,                           "Инерциальная система не откалибрована" ],
        [ /AHRS not healthy/gi,                             "AHRS неисправна" ],
        [ /AHRS: waiting for home/gi,                       "AHRS: ожидание точки старта" ],
        [ /waiting for home/gi,                             "ожидание точки старта" ],
        [ /EKF attitude is bad/gi,                          "EKF: неверная ориентация" ],
        [ /EKF variance/gi,                                 "EKF: большой разброс" ],
        [ /EKF failsafe/gi,                                 "EKF: аварийный режим" ],
        [ /(EKF\d?) waiting for GPS config data/gi,         "$1: ожидание настроек GPS" ],
        [ /(EKF\d?) IMU(\d+) is using GPS/gi,               "$1 IMU$2 использует GPS" ],
        [ /(EKF\d?) IMU(\d+) tilt alignment complete/gi,    "$1 IMU$2: выравнивание по наклону завершено" ],
        [ /(EKF\d?) IMU(\d+) MAG(\d+) initial yaw alignment complete/gi, "$1 IMU$2 MAG$3: начальный курс выставлен" ],
        [ /(EKF\d?) IMU(\d+) origin set/gi,                 "$1 IMU$2: начало координат задано" ],
        [ /Rangefinder (\d+): No Data/gi,                   "Эхолот/дальномер $1: нет данных" ],
        [ /Rangefinder (\d+): Not Detected/gi,              "Эхолот/дальномер $1: не обнаружен" ],
        [ /Rangefinder: No Data/gi,                         "Эхолот/дальномер: нет данных" ],
        [ /Internal errors? (0x[0-9a-fA-F]+)/gi,            "Внутренняя ошибка $1" ],

        // ---- GPS ----
        [ /GPS (\d+): Bad fix/gi,                           "GPS $1: плохое решение" ],
        [ /GPS (\d+): was not found/gi,                     "GPS $1: не найден" ],
        [ /GPS (\d+): not healthy/gi,                       "GPS $1: неисправен" ],
        [ /Need 3D Fix/gi,                                  "Нужно 3D-решение GPS" ],
        [ /Bad GPS Position/gi,                             "Плохие координаты GPS" ],
        [ /GPS and AHRS differ by ([\d.]+)m/gi,             "GPS и AHRS расходятся на $1 м" ],
        [ /GPS horiz error ([\d.]+)m/gi,                    "Горизонтальная ошибка GPS $1 м" ],
        [ /GPS vert error ([\d.]+)m/gi,                     "Вертикальная ошибка GPS $1 м" ],
        [ /GPS speed error ([\d.]+)/gi,                     "Ошибка скорости GPS $1" ],
        [ /GPS numsats/gi,                                  "Мало спутников GPS" ],
        [ /High GPS HDOP/gi,                                "Высокий HDOP GPS" ],
        [ /GPS Glitch cleared/gi,                           "Сбой GPS устранён" ],
        [ /GPS Glitch/gi,                                   "Сбой GPS" ],
        [ /GPS not healthy/gi,                              "GPS неисправен" ],
        [ /Waiting for GPS/gi,                              "Ожидание GPS" ],
        [ /u-blox (\d+) HW: ([^ ]+) SW: ([^ ]+)/gi,         "u-blox $1 аппарат.: $2 прогр.: $3" ],

        // ---- Battery / power ----
        [ /Battery (\d+) below minimum arming voltage/gi,   "Батарея $1 ниже минимального напряжения запуска" ],
        [ /Battery (\d+) below minimum arming capacity/gi,  "Батарея $1 ниже минимальной ёмкости запуска" ],
        [ /Battery (\d+) is critical/gi,                    "Батарея $1 критически разряжена" ],
        [ /Battery (\d+) is low/gi,                         "Батарея $1 разряжена" ],
        [ /Battery (\d+) low voltage failsafe/gi,           "Батарея $1: аварийный режим по напряжению" ],
        [ /Battery (\d+) critical voltage failsafe/gi,      "Батарея $1: критическое напряжение" ],
        [ /Battery (\d+) unhealthy/gi,                      "Батарея $1 неисправна" ],
        [ /Battery failsafe/gi,                             "Аварийный режим по батарее" ],
        [ /Check battery/gi,                                "Проверьте батарею" ],
        [ /Board \(([\d.]+)v\) out of range/gi,             "Питание платы ($1 В) вне диапазона" ],

        // ---- RC / GCS / failsafe ----
        [ /RC not calibrated/gi,                            "Пульт не откалиброван" ],
        [ /RC not found/gi,                                 "Пульт не найден" ],
        [ /Waiting for RC/gi,                               "Ожидание пульта" ],
        [ /Radio Failsafe - Disarming/gi,                   "Потеря пульта — моторы остановлены" ],
        [ /Radio Failsafe Cleared/gi,                       "Связь с пультом восстановлена" ],
        [ /Radio Failsafe/gi,                               "Потеря связи с пультом" ],
        [ /Failsafe: Radio/gi,                              "Аварийный режим: пульт" ],
        [ /GCS Failsafe Cleared/gi,                         "Связь с наземной станцией восстановлена" ],
        [ /GCS Failsafe/gi,                                 "Потеря связи с наземной станцией" ],
        [ /Failsafe Cleared/gi,                             "Аварийный режим снят" ],
        [ /Failsafe/gi,                                     "Аварийный режим" ],
        [ /Fence breached/gi,                               "Выход за геозону" ],
        [ /Fence enabled/gi,                                "Геозона включена" ],
        [ /Fence disabled/gi,                               "Геозона выключена" ],
        [ /Fence requires position/gi,                      "Геозоне нужны координаты" ],

        // ---- Mission / modes ----
        [ /Mission Complete/gi,                             "Задание выполнено" ],
        [ /Mission: (\d+) WP/gi,                            "Задание: точка $1" ],
        [ /Reached waypoint #(\d+) dist (\d+)m/gi,          "Достигнута точка №$1, расстояние $2 м" ],
        [ /Reached waypoint #(\d+)/gi,                      "Достигнута точка №$1" ],
        [ /Reached destination/gi,                          "Пункт назначения достигнут" ],
        [ /No Mission/gi,                                   "нет задания" ],
        [ /Mode change to ([A-Z_]+) failed/gi,              "Не удалось включить режим $1" ],
        [ /Flight mode change failed/gi,                    "Не удалось сменить режим" ],
        [ /Mode change failed/gi,                           "Не удалось сменить режим" ],
        [ /SmartRTL deactivated: bad position/gi,           "Умный возврат отключён: плохие координаты" ],
        [ /SmartRTL/g,                                      "Умный возврат" ],
        [ /Home set/gi,                                     "Точка старта задана" ],

        // ---- Logging / storage / scripting ----
        [ /Logging failed/gi,                               "Ошибка записи лога" ],
        [ /Logging not started/gi,                          "Запись лога не начата" ],
        [ /No SD card/gi,                                   "Нет SD-карты" ],
        [ /SD card not found/gi,                            "SD-карта не найдена" ],
        [ /Scripting: ([^ ]+) error/gi,                     "Скрипт $1: ошибка" ],
        [ /Scripting: out of memory/gi,                     "Скрипты: не хватает памяти" ],
        [ /Lua: (.+)/g,                                     "Lua: $1" ],

        // ---- QGC-side command results ----
        [ /Vehicle did not respond to command: (.+)/gi,     "Борт не ответил на команду: $1" ],
        [ /(.+) command temporarily rejected/gi,            "Команда «$1» временно отклонена" ],
        [ /(.+) command denied/gi,                          "Команда «$1» отклонена" ],
        [ /(.+) command failed/gi,                          "Команда «$1» не выполнена" ],
        [ /(.+) command not supported/gi,                   "Команда «$1» не поддерживается" ],
        [ /Vehicle (\d+): /g,                               "Борт $1: " ],

        // ---- Prefixes ----
        [ /PreArm: /g,                                      "Предстарт: " ],
        [ /Arm: /g,                                         "Запуск: " ],
        [ /Disarm: /g,                                      "Остановка: " ]
    ]

    function gidroLogTranslateMessage(message) {
        let text = String(message)
        for (let i = 0; i < _gidroLogMessageRules.length; i++) {
            const rule = _gidroLogMessageRules[i]
            rule[0].lastIndex = 0
            text = text.replace(rule[0], rule[1])
        }
        return text
    }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        if (suppressCriticalVehicleMessages) {
            return
        }
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional warning message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = gidroLogTranslateMessage(message)
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.placeAboveInstruments()
            criticalVehicleMessagePopup.open()
        }
    }

    // No focus and no Escape handler: either would steal keys from whatever the user is typing in.
    Popup {
        id:                 criticalVehicleMessagePopup
        objectName:         "criticalVehicleMessage_popup"
        // GidroLog: above the compass / pitch / roll block at the right edge (fallback: top centre)
        y:                  _anchorBottom > 0 ? Math.round(_anchorBottom - height - ScreenTools.defaultFontPixelHeight) : ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight
        x:                  _anchorRight > 0 ? Math.round(_anchorRight - width) : Math.round((mainWindow.width - width) * 0.5)
        width:              _anchorRight > 0 ? _anchorWidth : mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        closePolicy:        Popup.CloseOnPressOutside

        property alias  criticalVehicleMessage:             criticalVehicleMessageText.text
        property bool   additionalCriticalMessagesReceived: false
        property real   _anchorBottom:  0
        property real   _anchorRight:   0
        property real   _anchorWidth:   0

        function placeAboveInstruments() {
            const ip = mainWindow.gidroLogInstrumentPanel
            if (ip && ip.visible && ip.width > 0) {
                const p = ip.mapToItem(null, 0, 0)
                _anchorWidth  = Math.max(ip.width, ScreenTools.defaultFontPixelWidth * 40)
                _anchorRight  = p.x + ip.width
                _anchorBottom = p.y
            } else {
                _anchorRight  = 0
                _anchorBottom = 0
            }
        }

        function acknowledge() {
            close()
            if (additionalCriticalMessagesReceived) {
                additionalCriticalMessagesReceived = false
                flyView.dropMainStatusIndicatorTool()
            } else if (QGroundControl.multiVehicleManager.activeVehicle) {
                QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages()
            }
        }

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Сообщение борта")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Есть ещё сообщения")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            objectName:         "criticalVehicleMessage_text"
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: criticalVehicleMessagePopup.acknowledge()
        }
    }

    //-------------------------------------------------------------------------
    //-- Indicator Drawer

    function showIndicatorDrawer(drawerComponent, indicatorItem) {
        indicatorDrawer.sourceComponent = drawerComponent
        indicatorDrawer.indicatorItem = indicatorItem
        indicatorDrawer.open()
    }

    function closeIndicatorDrawer() {
        indicatorDrawer.close()
    }

    Popup {
        id:             indicatorDrawer
        x:              calcXPosition()
        y:              ScreenTools.toolbarHeight + _margins
        leftInset:      0
        rightInset:     0
        topInset:       0
        bottomInset:    0
        padding:        _margins * 2
        visible:        false
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var sourceComponent
        property var indicatorItem

        property bool _expanded:    false
        property real _margins:     ScreenTools.defaultFontPixelHeight / 4

        function calcXPosition() {
            if (indicatorItem) {
                var xCenter = indicatorItem.mapToItem(mainWindow.contentItem, indicatorItem.width / 2, 0).x
                return Math.max(_margins, Math.min(xCenter - (contentItem.implicitWidth / 2), mainWindow.contentItem.width - contentItem.implicitWidth - _margins - (indicatorDrawer.padding * 2) - (ScreenTools.defaultFontPixelHeight / 2)))
            } else {
                return _margins
            }
        }

        onOpened: {
            _expanded                               = false;
            indicatorDrawerLoader.sourceComponent   = indicatorDrawer.sourceComponent
        }
        onClosed: {
            _expanded                               = false
            indicatorItem                           = undefined
            indicatorDrawerLoader.sourceComponent   = undefined
        }

        background: Item {
            Rectangle {
                id:             backgroundRect
                anchors.fill:   parent
                color:          QGroundControl.globalPalette.window
                radius:         indicatorDrawer._margins
                opacity:        0.85
            }

            Rectangle {
                objectName:                 "indicatorDrawerExpandButton"
                anchors.horizontalCenter:   backgroundRect.right
                anchors.verticalCenter:     backgroundRect.top
                width:                      ScreenTools.largeFontPixelHeight
                height:                     width
                radius:                     width / 2
                color:                      QGroundControl.globalPalette.button
                border.color:               QGroundControl.globalPalette.buttonText
                visible:                    indicatorDrawerLoader.item && indicatorDrawerLoader.item._showExpand && !indicatorDrawer._expanded

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               ">"
                    color:              QGroundControl.globalPalette.buttonText
                }

                QGCMouseArea {
                    fillItem: parent
                    onClicked: indicatorDrawer._expanded = true
                }
            }
        }

        contentItem: QGCFlickable {
            id:             indicatorDrawerLoaderFlickable
            implicitWidth:  Math.min(mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.width)
            implicitHeight: Math.min(mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.height)
            contentWidth:   indicatorDrawerLoader.width
            contentHeight:  indicatorDrawerLoader.height

            Loader {
                id:         indicatorDrawerLoader
                objectName: "indicatorDrawerLoader"

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "expanded"
                    value:      indicatorDrawer._expanded
                }

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "drawer"
                    value:      indicatorDrawer
                }
            }
        }
    }

    // Analyze page items (both in-panel and popped-out windows) are created with mainWindow as their
    // QObject parent so their lifetime is not tied to AnalyzeView. This lets a popped-out window
    // survive AnalyzeView being unloaded from the tool drawer.

    // Tracks the analyze page item currently shown inside AnalyzeView's panel (not popped out).
    // null when no page is loaded or the item has been handed off to a popup window.
    property var _inPanelAnalyzePage: null

    // Called by AnalyzeView.Component.onDestruction to destroy the in-panel item while
    // panelContainer is still alive.
    function destroyInPanelAnalyzePage() {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy()
            _inPanelAnalyzePage = null
        }
    }

    // Called by AnalyzeView to create an analyze page item owned by mainWindow.
    // The caller sets the visual parent to panelContainer after creation.
    function createAnalyzePage(source) {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy()
            _inPanelAnalyzePage = null
        }
        var component = Qt.createComponent(source)
        if (component.status !== Component.Ready) {
            console.warn("createAnalyzePage failed source:", source, "errorString:", component.errorString())
            return null
        }
        _inPanelAnalyzePage = component.createObject(mainWindow)
        return _inPanelAnalyzePage
    }

    // Called by AnalyzeView when the in-panel item is handed off to a popup window.
    // Clears _inPanelAnalyzePage so destroyInPanelAnalyzePage() does not destroy it
    // when AnalyzeView is torn down.
    function analyzePageMovedToPopup() {
        _inPanelAnalyzePage = null
    }

    function createWindowedAnalyzePage(title, source, requiresVehicle, existingItem) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.requiresVehicle = requiresVehicle
        if (existingItem) {
            windowedPage.adoptItem(existingItem)
        } else {
            windowedPage.source = source
        }
        windowedPage.visible = true
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    false

            property alias source: loader.source
            property bool requiresVehicle: false

            function adoptItem(item) {
                loader.visible = false
                loader.source = ""
                item.parent = contentRect
                item.anchors.fill = contentRect
                item.popped = true
                item.visible = true
            }

            Connections {
                target: QGroundControl.multiVehicleManager
                function onActiveVehicleChanged() {
                    if (requiresVehicle) {
                        close()
                    }
                }
            }

            Rectangle {
                id:             contentRect
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }

            onClosing: {
                visible = false
                // Destroy any reparented children (not owned by loader)
                for (var i = contentRect.children.length - 1; i >= 0; i--) {
                    var child = contentRect.children[i]
                    if (child !== loader) {
                        child.destroy()
                    }
                }
                source = ""
                Qt.callLater(destroy)
            }
        }
    }
}
