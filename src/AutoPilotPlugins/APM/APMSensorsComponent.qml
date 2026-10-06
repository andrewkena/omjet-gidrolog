import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SetupPage {
    id:             sensorsPage
    pageComponent:  sensorsPageComponent

    Component {
        id:             sensorsPageComponent

        Item {
            width:  availableWidth
            height: availableHeight

            // Help text which is shown both in the status text area prior to pressing a cal button and in the
            // pre-calibration dialog.

            readonly property string orientationHelpSet:    qsTr("Если установлен по направлению движения, выберите «Нет».")
            readonly property string orientationHelpCal:    qsTr("Перед калибровкой проверьте настройки ориентации. ") + orientationHelpSet
            readonly property string compassRotationText:   qsTr("Если компас или модуль GPS установлен по направлению движения, оставьте значение по умолчанию («Нет»)")

            readonly property string compassHelp:   qsTr("Для калибровки компаса нужно повернуть судно в несколько положений.")
            readonly property string gyroHelp:      qsTr("Для калибровки гироскопа поставьте судно на поверхность и не двигайте его.")
            readonly property string accelHelp:     qsTr("Для калибровки акселерометра ставьте судно на ровную поверхность на каждую из шести сторон и удерживайте неподвижно несколько секунд.")
            readonly property string levelHelp:     qsTr("Для выставления горизонта установите судно ровно и нажмите OK.")

            readonly property string statusTextAreaDefaultText: qsTr("Начните пошаговую калибровку, нажав одну из кнопок слева.")

            // Used to pass help text to the preCalibrationDialog dialog
            property string preCalibrationDialogHelp

            property string _postCalibrationDialogText
            property var    _postCalibrationDialogParams

            readonly property string _badCompassCalText: qsTr("Калибровка компаса %1, похоже, плохая. ") +
                                                         qsTr("Проверьте положение компаса на судне и повторите калибровку.")

            readonly property int sideBarH1PointSize:  ScreenTools.mediumFontPointSize
            readonly property int mainTextH1PointSize: ScreenTools.mediumFontPointSize // Seems to be unused

            readonly property int rotationColumnWidth: 250

            property Fact noFact: Fact { }

            property bool accelCalNeeded:                   controller.accelSetupNeeded
            property bool compassCalNeeded:                 controller.compassSetupNeeded

            property Fact boardRot:                         controller.getParameterFact(-1, "AHRS_ORIENTATION")

            readonly property int _calTypeCompass:  1   ///< Calibrate compass
            readonly property int _calTypeAccel:    2   ///< Calibrate accel
            readonly property int _calTypeSet:      3   ///< Set orientations only
            readonly property int _buttonWidth:     ScreenTools.defaultFontPixelWidth * 15

            property bool   _orientationsDialogShowCompass: true
            property string _orientationDialogHelp:         orientationHelpSet
            property int    _orientationDialogCalType
            property real   _margins:                       ScreenTools.defaultFontPixelHeight / 2
            property bool   _compassAutoRotAvailable:       controller.parameterExists(-1, "COMPASS_AUTO_ROT")
            property Fact   _compassAutoRotFact:            controller.getParameterFact(-1, "COMPASS_AUTO_ROT", false /* reportMissing */)
            property bool   _compassAutoRot:                _compassAutoRotAvailable ? _compassAutoRotFact.rawValue == 2 : false
            property bool   _showSimpleAccelCalOption:      false
            property bool   _doSimpleAccelCal:              false
            property var    _gcsPosition:                    QGroundControl.qgcPositionManger.gcsPosition
            property var    _mapPosition:                    QGroundControl.flightMapPosition

            function showOrientationsDialog(calType) {
                let dialogTitle
                let dialogButtons = Dialog.Ok
                _showSimpleAccelCalOption = false

                _orientationDialogCalType = calType
                switch (calType) {
                case _calTypeCompass:
                    _orientationsDialogShowCompass = true
                    _orientationDialogHelp = orientationHelpCal
                    dialogTitle = qsTr("Калибровка компаса")
                    dialogButtons |= Dialog.Cancel
                    break
                case _calTypeAccel:
                    _orientationsDialogShowCompass = false
                    _orientationDialogHelp = orientationHelpCal
                    dialogTitle = qsTr("Калибровка акселерометра")
                    dialogButtons |= Dialog.Cancel
                    break
                case _calTypeSet:
                    _orientationsDialogShowCompass = true
                    _orientationDialogHelp = orientationHelpSet
                    dialogTitle = qsTr("Настройки датчиков")
                    break
                }

                orientationsDialogFactory.open({ title: dialogTitle, buttons: dialogButtons })
            }

            function showSimpleAccelCalOption() {
                _showSimpleAccelCalOption = true
            }

            // Maps the APM controller per-side done/inProgress bools to a VehicleRotationCal.CalState
            function sideCalState(done, inProgress) {
                if (inProgress) {
                    return VehicleRotationCal.CalState.InProgress
                }
                return done ? VehicleRotationCal.CalState.Completed : VehicleRotationCal.CalState.Incomplete
            }

            function compassLabel(index) {
                let label = qsTr("Компас %1 ").arg(index+1)
                let addOpenParan = true
                let addComma = false
                if (sensorParams.compassPrimaryFactAvailable) {
                    label += sensorParams.rgCompassPrimary[index] ? qsTr("(основной") : qsTr("(резервный")
                    addComma = true
                    addOpenParan = false
                }
                if (sensorParams.rgCompassExternalParamAvailable[index]) {
                    if (addOpenParan) {
                        label += "("
                    }
                    if (addComma) {
                        label += qsTr(", ")
                    }
                    label += sensorParams.rgCompassExternal[index] ? qsTr("внешний") : qsTr("внутренний")
                }
                label += ")"
                return label
            }

            APMSensorParams {
                id:                     sensorParams
                factPanelController:    controller
            }

            APMSensorsComponentController {
                id:                         controller
                statusLog:                  statusTextArea
                progressBar:                progressBar
                nextButton:                 nextButton
                cancelButton:               cancelButton
                orientationCalAreaHelpText: orientationCalAreaHelpText

                property var rgCompassCalFitness: [ controller.compass1CalFitness, controller.compass2CalFitness, controller.compass3CalFitness ]

                onResetStatusTextArea: statusLog.text = statusTextAreaDefaultText

                onWaitingForCancelChanged: {
                    if (controller.waitingForCancel) {
                        waitForCancelDialogFactory.open()
                    }
                }

                onCalibrationComplete: (calType) => {
                    switch (calType) {
                    case MAVLink.CalibrationMag:
                        _singleCompassSettingsComponentShowPriority = true
                        postOnboardCompassCalibrationFactory.open()
                        break
                    case MAVLink.CalibrationAccel:
                        postCalibrationFactory.open()
                        break
                    }
                }

                onSetAllCalButtonsEnabled: (enabled) => {
                    buttonColumn.enabled = enabled
                }

                onCalibrationActiveChanged: {
                    if (controller.calibrationActive) {
                        globals.navigationBlockedReason = qsTr("Сначала завершите или отмените текущую калибровку")
                    } else {
                        globals.navigationBlockedReason = ""
                    }
                }
            }

            Component.onDestruction: globals.navigationBlockedReason = ""

            QGCPalette { id: qgcPal; colorGroupEnabled: true }

            QGCPopupDialogFactory {
                id: waitForCancelDialogFactory

                dialogComponent: waitForCancelDialogComponent
            }

            Component {
                id: waitForCancelDialogComponent

                QGCSimpleMessageDialog {
                    title:      qsTr("Отмена калибровки")
                    text:       qsTr("Ожидание ответа судна на отмену. Это может занять несколько секунд.")
                    buttons:    0

                    Connections {
                        target: controller

                        onWaitingForCancelChanged: {
                            if (!controller.waitingForCancel) {
                                close()
                            }
                        }
                    }
                }
            }

            Component {
                id: singleCompassOnboardResultsComponent

                Column {
                    anchors.left:   parent ? parent.left : undefined
                    anchors.right:  parent ? parent.right : undefined
                    spacing:        Math.round(ScreenTools.defaultFontPixelHeight / 2)
                    visible:        sensorParams.rgCompassAvailable[index] && sensorParams.rgCompassUseFact[index].value

                    property int _index: index

                    property real greenMaxThreshold:   8 * (sensorParams.rgCompassExternal[index] ? 1 : 2)
                    property real yellowMaxThreshold:  15 * (sensorParams.rgCompassExternal[index] ? 1 : 2)
                    property real fitnessRange:        25 * (sensorParams.rgCompassExternal[index] ? 1 : 2)

                    Item {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        height:         ScreenTools.defaultFontPixelHeight

                        Row {
                            id:             fitnessRow
                            anchors.fill:   parent

                            Rectangle {
                                width:  parent.width * (greenMaxThreshold / fitnessRange)
                                height: parent.height
                                color:  "green"
                            }
                            Rectangle {
                                width:  parent.width * ((yellowMaxThreshold - greenMaxThreshold) / fitnessRange)
                                height: parent.height
                                color:  "yellow"
                            }
                            Rectangle {
                                width:  parent.width * ((fitnessRange - yellowMaxThreshold) / fitnessRange)
                                height: parent.height
                                color:  "red"
                            }
                        }

                        Rectangle {
                            height:                 fitnessRow.height * 0.66
                            width:                  height
                            anchors.verticalCenter: fitnessRow.verticalCenter
                            x:                      (fitnessRow.width * (Math.min(Math.max(controller.rgCompassCalFitness[index], 0.0), fitnessRange) / fitnessRange)) - (width / 2)
                            radius:                 height / 2
                            color:                  "white"
                            border.color:           "black"
                        }
                    }

                    Loader {
                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        sourceComponent:    singleCompassSettingsComponent

                        property int index: _index
                    }
                }
            }

            QGCPopupDialogFactory {
                id: postOnboardCompassCalibrationFactory

                dialogComponent: postOnboardCompassCalibrationComponent
            }

            Component {
                id: postOnboardCompassCalibrationComponent

                QGCPopupDialog {
                    id:         postOnboardCompassCalibrationDialog
                    title:      qsTr("Калибровка завершена")
                    buttons:    Dialog.Ok

                    Column {
                        objectName: "postOnboardCompassCalibrationDialog"
                        width:      40 * ScreenTools.defaultFontPixelWidth
                        spacing:    ScreenTools.defaultFontPixelHeight

                        Repeater {
                            model:      3
                            delegate:   singleCompassOnboardResultsComponent
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Полосы показывают качество калибровки каждого компаса.\n\n") +
                                            qsTr("- Зелёный — компас работает хорошо.\n") +
                                            qsTr("- Жёлтый — сомнительный компас или калибровка.\n") +
                                            qsTr("- Красный — компас использовать нельзя.\n\n") +
                                            qsTr("ПОСЛЕ КАЖДОЙ КАЛИБРОВКИ ПЕРЕЗАГРУЖАЙТЕ СУДНО.")
                        }

                        QGCButton {
                            text:       qsTr("Перезагрузить судно")
                            onClicked: {
                                controller.vehicle.rebootVehicle()
                                postOnboardCompassCalibrationDialog.close()
                            }
                        }
                    }
                }
            }

            QGCPopupDialogFactory {
                id: postCalibrationFactory

                dialogComponent: postCalibrationComponent
            }

            Component {
                id: postCalibrationComponent

                QGCPopupDialog {
                    id:     postCalibrationDialog
                    title:  qsTr("Калибровка завершена")

                    Column {
                        objectName: "postCalibrationDialog"
                        width:      40 * ScreenTools.defaultFontPixelWidth
                        spacing:    ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("ПОСЛЕ КАЖДОЙ КАЛИБРОВКИ ПЕРЕЗАГРУЖАЙТЕ СУДНО.")
                        }

                        QGCButton {
                            text:       qsTr("Перезагрузить судно")
                            onClicked: {
                                controller.vehicle.rebootVehicle()
                                postCalibrationDialog.close()
                            }
                        }
                    }
                }
            }

            property bool _singleCompassSettingsComponentShowPriority: true
            Component {
                id: singleCompassSettingsComponent

                Column {
                    spacing: Math.round(ScreenTools.defaultFontPixelHeight / 2)
                    visible: sensorParams.rgCompassAvailable[index]

                    QGCLabel {
                        text: compassLabel(index)
                    }
                    APMSensorIdDecoder {
                        fact: sensorParams.rgCompassId[index]
                    }

                    Column {
                        anchors.margins:    ScreenTools.defaultFontPixelWidth * 2
                        anchors.left:       parent.left
                        spacing:            Math.round(ScreenTools.defaultFontPixelHeight / 4)

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth

                            FactCheckBox {
                                id:         useCompassCheckBox
                                text:       qsTr("Использовать компас")
                                fact:       sensorParams.rgCompassUseFact[index]
                                visible:    sensorParams.rgCompassUseParamAvailable[index] && !sensorParams.rgCompassPrimary[index]
                            }

                            QGCComboBox {
                                model:      [ qsTr("Приоритет 1"), qsTr("Приоритет 2"), qsTr("Приоритет 3"), qsTr("Не задан") ]
                                visible:    _singleCompassSettingsComponentShowPriority && sensorParams.compassPrioFactsAvailable && useCompassCheckBox.visible && useCompassCheckBox.checked

                                property int _compassIndex: index

                                function selectPriorityfromParams() {
                                    currentIndex = 3
                                    let compassId = sensorParams.rgCompassId[_compassIndex].rawValue
                                    for (let prioIndex=0; prioIndex<3; prioIndex++) {
                                        if (compassId == sensorParams.rgCompassPrio[prioIndex].rawValue) {
                                            currentIndex = prioIndex
                                            break
                                        }
                                    }
                                }

                                Component.onCompleted: selectPriorityfromParams()

                                onActivated: (index) => {
                                    if (index == 3) {
                                        // User cannot select Not Set
                                        selectPriorityfromParams()
                                    } else {
                                        sensorParams.rgCompassPrio[index].rawValue = sensorParams.rgCompassId[_compassIndex].rawValue
                                    }
                                }
                            }
                        }

                        Column {
                            visible: !_compassAutoRot && sensorParams.rgCompassExternal[index] && sensorParams.rgCompassRotParamAvailable[index]

                            QGCLabel { text: qsTr("Ориентация:") }

                            FactComboBox {
                                width:      rotationColumnWidth
                                indexModel: false
                                fact:       sensorParams.rgCompassRotFact[index]
                            }
                        }
                    }
                }
            }

            QGCPopupDialogFactory {
                id: orientationsDialogFactory

                dialogComponent: orientationsDialogComponent
            }

            Component {
                id: orientationsDialogComponent

                QGCPopupDialog {
                    function compassMask () {
                        let mask = 0
                        mask |=  (0 + (sensorParams.rgCompassPrio[0].rawValue !== 0)) << 0
                        mask |=  (0 + (sensorParams.rgCompassPrio[1].rawValue !== 0)) << 1
                        mask |=  (0 + (sensorParams.rgCompassPrio[2].rawValue !== 0)) << 2
                        return mask
                    }

                    onAccepted: {
                        if (_orientationDialogCalType == _calTypeAccel) {
                            controller.calibrateAccel(_doSimpleAccelCal)
                        } else if (_orientationDialogCalType == _calTypeCompass) {
                            if (!northCalibrationCheckBox.checked) {
                                controller.calibrateCompass()
                            } else {
                                let lat = parseFloat(northCalLat.text)
                                let lon = parseFloat(northCalLon.text)
                                if (useMapPositionCheckbox.checked) {
                                    lat = _mapPosition.latitude
                                    lon = _mapPosition.longitude
                                }
                                if (useGcsPositionCheckbox.checked) {
                                    lat = _gcsPosition.latitude
                                    lon = _gcsPosition.longitude
                                }
                                if (isNaN(lat) || isNaN(lon)) {
                                    return
                                }
                                controller.calibrateCompassNorth(lat, lon, compassMask())
                            }
                        }
                    }

                    Column {
                        width:      40 * ScreenTools.defaultFontPixelWidth
                        spacing:    ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            width:      parent.width
                            wrapMode:   Text.WordWrap
                            text:       _orientationDialogHelp
                        }

                        Column {
                            QGCLabel { text: qsTr("Поворот автопилота:") }

                            FactComboBox {
                                width:      rotationColumnWidth
                                indexModel: false
                                fact:       boardRot
                            }
                        }

                        Column {

                            visible: _orientationDialogCalType == _calTypeAccel
                            spacing: ScreenTools.defaultFontPixelHeight

                            QGCLabel {
                                width:      parent.width
                                wrapMode:   Text.WordWrap
                                text: qsTr("Упрощённая калибровка акселерометра менее точна, но не требует переворачивать судно. Подходит для больших и тяжёлых судов.")
                            }

                            QGCCheckBox {
                                text: qsTr("Упрощённая калибровка акселерометра")
                                onClicked: _doSimpleAccelCal = this.checked
                            }
                        }

                        Repeater {
                            model:      _orientationsDialogShowCompass ? 3 : 0
                            delegate:   singleCompassSettingsComponent
                        }

                        QGCLabel {
                            id:         magneticDeclinationLabel
                            width:      parent.width
                            visible:    globals.activeVehicle.sub && _orientationsDialogShowCompass
                            text:       qsTr("Магнитное склонение")
                        }

                        Column {
                            visible:            magneticDeclinationLabel.visible
                            anchors.margins:    ScreenTools.defaultFontPixelWidth
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            spacing:            ScreenTools.defaultFontPixelHeight

                            QGCCheckBox {
                                id:                           manualMagneticDeclinationCheckBox
                                text:                         qsTr("Ручное магнитное склонение")
                                property Fact autoDecFact:    controller.getParameterFact(-1, "COMPASS_AUTODEC")
                                property int manual:          0
                                property int automatic:       1

                                checked:    autoDecFact.rawValue === manual
                                onClicked:  autoDecFact.value = (checked ? manual : automatic)
                            }

                            FactTextField {
                                fact:       sensorParams.declinationFact
                                enabled:    manualMagneticDeclinationCheckBox.checked
                            }
                        }

                        Item { height: ScreenTools.defaultFontPixelHeight; width: 10 } // spacer

                        QGCLabel {
                            id:         northCalibrationLabel
                            width:      parent.width
                            visible:    _orientationsDialogShowCompass
                            wrapMode:   Text.WordWrap
                            text:       qsTr("Быстрая калибровка компаса по позиции и курсу судна. ") +
                                        qsTr("Диагональные и внедиагональные коэффициенты обнуляются, поэтому ") +
                                        qsTr("подходит только при почти сферическом поле. ") +
                                        qsTr("Удобно для больших судов, которые трудно ") +
                                        qsTr("вращать при калибровке. Перед запуском направьте судно на север.")
                        }

                        Column {
                            visible:            northCalibrationLabel.visible
                            anchors.margins:    ScreenTools.defaultFontPixelWidth
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            spacing:            ScreenTools.defaultFontPixelHeight

                            QGCCheckBox {
                                id:             northCalibrationCheckBox
                                visible:        northCalibrationLabel.visible
                                text:           qsTr("Быстрая калибровка")
                            }

                            QGCLabel {
                                id:         northCalibrationManualPosition
                                width:      parent.width
                                visible:    northCalibrationCheckBox.checked && !globals.activeVehicle.coordinate.isValid
                                wrapMode:   Text.WordWrap
                                text:       qsTr("У судна нет достоверной позиции, укажите её")
                            }

                            QGCCheckBox {
                                visible:    northCalibrationManualPosition.visible && _gcsPosition.isValid
                                id:         useGcsPositionCheckbox
                                text:       qsTr("Использовать позицию станции")
                                checked:    _gcsPosition.isValid
                            }
                            QGCCheckBox {
                                visible:    northCalibrationManualPosition.visible && !_gcsPosition.isValid
                                id:         useMapPositionCheckbox
                                text:       qsTr("Использовать позицию на карте")
                            }

                            QGCLabel {
                                width:      parent.width
                                visible:    useMapPositionCheckbox.checked
                                wrapMode:   Text.WordWrap
                                //: %1 is latitude, %2 is longitude
                                text:       qsTr("Шир: %1 Долг: %2").arg(_mapPosition.latitude.toFixed(4)).arg(_mapPosition.longitude.toFixed(4))
                            }

                            FactTextField {
                                id:         northCalLat
                                visible:    !useGcsPositionCheckbox.checked && !useMapPositionCheckbox.checked && northCalibrationCheckBox.checked
                                text:       "0.00"
                                textColor:  isNaN(parseFloat(text)) ? qgcPal.warningText: qgcPal.textFieldText
                                enabled:    !useGcsPositionCheckbox.checked
                            }
                            FactTextField {
                                id:         northCalLon
                                visible:    !useGcsPositionCheckbox.checked && !useMapPositionCheckbox.checked && northCalibrationCheckBox.checked
                                text:       "0.00"
                                textColor:  isNaN(parseFloat(text)) ? qgcPal.warningText: qgcPal.textFieldText
                                enabled:    !useGcsPositionCheckbox.checked
                            }

                        }
                    }
                }
            }

            QGCPopupDialogFactory {
                id: compassMotDialogFactory

                dialogComponent: compassMotDialogComponent
            }

            Component {
                id: compassMotDialogComponent

                QGCPopupDialog {
                    title:      qsTr("Калибровка помех от моторов на компас")
                    buttons:    Dialog.Cancel | Dialog.Ok

                    onAccepted: controller.calibrateMotorInterference()

                    Column {
                        width:      40 * ScreenTools.defaultFontPixelWidth
                        spacing:    ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Рекомендуется для судов только со встроенным компасом или с сильными помехами от моторов, силовых проводов и т. п. ") +
                                            qsTr("CompassMot хорошо работает только с датчиком тока, так как помехи пропорциональны току. ") +
                                            qsTr("Настройка CompassMot по газу возможна, но не рекомендуется.")
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Снимите винты, переверните их и переставьте на одну позицию по кругу. ") +
                                            qsTr("В таком положении при увеличении газа они должны прижимать аппарат к земле.")
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Закрепите аппарат (например, скотчем), чтобы он не двигался.")
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Включите пульт и держите газ на нуле.")
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Нажмите OK, чтобы начать калибровку CompassMot.")
                        }
                    }
                }
            }

            QGCFlickable {
                id:             buttonFlickable
                anchors.left:   parent.left
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                width:          _buttonWidth
                contentHeight:  nextCancelColumn.y + nextCancelColumn.height + _margins

                // Calibration button column - Calibratin buttons are kept in a separate column from Next/Cancel buttons
                // so we can enable/disable them all as a group
                Column {
                    id:                 buttonColumn
                    spacing:            _margins
                    Layout.alignment:   Qt.AlignLeft | Qt.AlignTop

                    IndicatorButton {
                        objectName:     "sensorsSetup_calibrateAccel"
                        width:          _buttonWidth
                        text:           qsTr("Акселерометр")
                        indicatorGreen: !accelCalNeeded

                        onClicked: function () {
                            showOrientationsDialog(_calTypeAccel);
                            showSimpleAccelCalOption();
                        }
                    }

                    IndicatorButton {
                        objectName:     "sensorsSetup_calibrateCompass"
                        width:          _buttonWidth
                        text:           qsTr("Компас")
                        indicatorGreen: !compassCalNeeded

                        onClicked: {
                            if (controller.accelSetupNeeded) {
                                QGroundControl.showMessageDialog(sensorsPage, qsTr("Калибровка компаса"), qsTr("Акселерометр нужно откалибровать до компаса."))
                            } else {
                                showOrientationsDialog(_calTypeCompass)
                            }
                        }
                    }

                    QGCButton {
                        width:  _buttonWidth
                        text:   _levelHorizonText

                        readonly property string _levelHorizonText: qsTr("Выставление горизонта")

                        onClicked: {
                            if (controller.accelSetupNeeded) {
                                QGroundControl.showMessageDialog(sensorsPage, _levelHorizonText, qsTr("Акселерометр нужно откалибровать до выставления горизонта."))
                            } else {
                                QGroundControl.showMessageDialog(sensorsPage, _levelHorizonText,
                                                             qsTr("Для выставления горизонта установите судно ровно и нажмите OK."),
                                                             Dialog.Cancel | Dialog.Ok,
                                                             function() { controller.levelHorizon() })
                            }
                        }
                    }

                    QGCButton {
                        width:      _buttonWidth
                        text:       qsTr("Гироскоп")
                        visible:    globals.activeVehicle && (globals.activeVehicle.multiRotor | globals.activeVehicle.rover | globals.activeVehicle.sub)
                        onClicked:  QGroundControl.showMessageDialog(sensorsPage, qsTr("Калибровка гироскопа"),
                                                                 qsTr("Для калибровки гироскопа поставьте судно на поверхность и не двигайте его.\n\nНажмите OK, чтобы начать."),
                                                                 Dialog.Cancel | Dialog.Ok,
                                                                 function() { controller.calibrateGyro() })
                    }

                    QGCButton {
                        width:      _buttonWidth
                        text:       _calibratePressureText
                        onClicked:  QGroundControl.showMessageDialog(sensorsPage, _calibratePressureText,
                                                                 qsTr("Калибровка давления обнулит %1 при текущем давлении. %2").arg(_altText).arg(_helpTextFW),
                                                                 Dialog.Cancel | Dialog.Ok,
                                                                 function() { controller.calibratePressure() })

                        readonly property string _altText:                  globals.activeVehicle.sub ? qsTr("глубину") : qsTr("высоту")
                        readonly property string _helpTextFW:               globals.activeVehicle.fixedWing ? qsTr("Для калибровки датчика воздушной скорости закройте его от ветра. Не трогайте датчик и не закрывайте отверстия.") : ""
                        readonly property string _calibratePressureText:    globals.activeVehicle.fixedWing ? qsTr("Баро/скорость") : qsTr("Давление")
                    }

                    QGCButton {
                        width:      _buttonWidth
                        text:       qsTr("CompassMot")
                        visible:    globals.activeVehicle ? globals.activeVehicle.supports.motorInterference : false
                        onClicked:  compassMotDialogFactory.open()
                    }

                    QGCButton {
                        width:      _buttonWidth
                        text:       qsTr("Настройки датчиков")
                        onClicked:  showOrientationsDialog(_calTypeSet)
                    }
                } // Column - Cal Buttons

                Column {
                    id:                 nextCancelColumn
                    anchors.topMargin:  buttonColumn.spacing
                    anchors.top:        buttonColumn.bottom
                    anchors.left:       buttonColumn.left
                    spacing:            buttonColumn.spacing

                    QGCButton {
                        id:         nextButton
                        objectName: "sensorsSetup_nextButton"
                        width:      _buttonWidth
                        text:       qsTr("Далее")
                        enabled:    false
                        onClicked:  controller.nextClicked()
                    }

                    QGCButton {
                        id:             cancelButton
                        objectName:     "sensorsSetup_cancelButton"
                        width:          _buttonWidth
                        text:           qsTr("Отмена")
                        enabled:        false
                        onClicked:      controller.cancelCalibration()
                    }
                }
            } // QGCFlickable - buttons

            /// Right column - cal area
            Column {
                anchors.leftMargin: _margins
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                anchors.left:       buttonFlickable.right
                anchors.right:      parent.right

                ProgressBar {
                    id:             progressBar
                    objectName:     "sensorsSetup_progressBar"
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                }

                Item { height: ScreenTools.defaultFontPixelHeight; width: 10 } // spacer

                Item {
                    id:     centerPanel
                    width:  parent.width
                    height: parent.height - y

                    TextArea {
                        id:             statusTextArea
                        anchors.fill:   parent
                        readOnly:       true
                        text:           statusTextAreaDefaultText
                        color:          qgcPal.text
                        background:     Rectangle { color: qgcPal.windowShade }
                    }

                    Rectangle {
                        id:             orientationCalArea
                        anchors.fill:   parent
                        visible:        controller.showOrientationCalArea
                        color:          qgcPal.windowShade

                        QGCLabel {
                            id:                 orientationCalAreaHelpText
                            anchors.margins:    ScreenTools.defaultFontPixelWidth
                            anchors.top:        orientationCalArea.top
                            anchors.left:       orientationCalArea.left
                            width:              parent.width
                            wrapMode:           Text.WordWrap
                            font.pointSize:     ScreenTools.mediumFontPointSize
                        }

                        Flow {
                            anchors.topMargin:  ScreenTools.defaultFontPixelWidth
                            anchors.top:        orientationCalAreaHelpText.bottom
                            anchors.bottom:     parent.bottom
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            spacing:            ScreenTools.defaultFontPixelWidth

                            property real indicatorWidth:   (width / 3) - (spacing * 2)
                            property real indicatorHeight:  (height / 2) - spacing

                            VehicleRotationCal {
                                objectName:         "sensorsCal_downSide"
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalDownSideVisible
                                calState:           sideCalState(controller.orientationCalDownSideDone, controller.orientationCalDownSideInProgress)
                                calInProgressText:  controller.orientationCalDownSideRotate ? qsTr("Поверните") : qsTr("Не двигайте")
                                imageSource:        "qrc:///qmlimages/VehicleDown.png"
                            }
                            VehicleRotationCal {
                                objectName:         "sensorsCal_leftSide"
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalLeftSideVisible
                                calState:           sideCalState(controller.orientationCalLeftSideDone, controller.orientationCalLeftSideInProgress)
                                calInProgressText:  controller.orientationCalLeftSideRotate ? qsTr("Поверните") : qsTr("Не двигайте")
                                imageSource:        "qrc:///qmlimages/VehicleLeft.png"
                            }
                            VehicleRotationCal {
                                objectName:         "sensorsCal_rightSide"
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalRightSideVisible
                                calState:           sideCalState(controller.orientationCalRightSideDone, controller.orientationCalRightSideInProgress)
                                calInProgressText:  controller.orientationCalRightSideRotate ? qsTr("Поверните") : qsTr("Не двигайте")
                                imageSource:        "qrc:///qmlimages/VehicleRight.png"
                            }
                            VehicleRotationCal {
                                objectName:         "sensorsCal_noseDownSide"
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalNoseDownSideVisible
                                calState:           sideCalState(controller.orientationCalNoseDownSideDone, controller.orientationCalNoseDownSideInProgress)
                                calInProgressText:  controller.orientationCalNoseDownSideRotate ? qsTr("Поверните") : qsTr("Не двигайте")
                                imageSource:        "qrc:///qmlimages/VehicleNoseDown.png"
                            }
                            VehicleRotationCal {
                                objectName:         "sensorsCal_tailDownSide"
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalTailDownSideVisible
                                calState:           sideCalState(controller.orientationCalTailDownSideDone, controller.orientationCalTailDownSideInProgress)
                                calInProgressText:  controller.orientationCalTailDownSideRotate ? qsTr("Поверните") : qsTr("Не двигайте")
                                imageSource:        "qrc:///qmlimages/VehicleTailDown.png"
                            }
                            VehicleRotationCal {
                                objectName:         "sensorsCal_upsideDownSide"
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalUpsideDownSideVisible
                                calState:           sideCalState(controller.orientationCalUpsideDownSideDone, controller.orientationCalUpsideDownSideInProgress)
                                calInProgressText:  controller.orientationCalUpsideDownSideRotate ? qsTr("Поверните") : qsTr("Не двигайте")
                                imageSource:        "qrc:///qmlimages/VehicleUpsideDown.png"
                            }
                        }
                    }
                } // Item - Cal display area
            } // Column - cal display
        } // Row
    } // Component - sensorsPageComponent
} // SetupPage
