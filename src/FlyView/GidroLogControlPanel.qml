import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// GidroLog: boat control panel (left side, under the depth legend)
//   ARM        - hold 2 s to arm / disarm, red while armed
//   STOP       - motor emergency stop (ArduPilot aux function MOTOR_ESTOP) on press, blinks red while engaged;
//                hold 2 s to release the emergency stop
//   Manual / AUTO / Smart RTL / RTL - hold 2 s to switch mode, current mode is green
//   siren / beacon indicators - red while the assigned channel is on (channels to be assigned)
//   photo pin - blinks blue on each camera trigger
Item {
    id:             control
    implicitWidth:  mainLayout.implicitWidth + (_margin * 2)
    implicitHeight: mainLayout.implicitHeight + (_margin * 2)

    property var  vehicle:          QGroundControl.multiVehicleManager.activeVehicle
    property var  _settings:        mainWindow.gidroLogSettings
    property var  _rcChannels:      []      // latest RC_CHANNELS PWM values
    property bool _estopEngaged:    false   // motor emergency stop sent and not released yet
    property bool sirenActive:      _channelOn(_settings.sirenChannel, _settings.sirenThreshold)
    property bool beaconActive:     _channelOn(_settings.beaconChannel, _settings.beaconThreshold)

    // GidroLog: motor emergency stop switch on the transmitter, linked with the STOP button.
    // Channel: from the settings, or (auto) the one with RCx_OPTION = 31 on the autopilot.
    property int  _estopChannel:    _settings.estopChannel >= 0 ? _settings.estopChannel : _autoEstopChannel
    property int  _autoEstopChannel: _findEstopChannel()
    property bool estopRcActive:    _estopChannel > 0 && _channelOn(_estopChannel, _settings.estopThreshold)

    onEstopRcActiveChanged: _estopEngaged = estopRcActive

    // GidroLog: photo trigger indicator - blinks for a moment on every camera trigger
    // (CAMERA_IMAGE_CAPTURED / CAMERA_FEEDBACK from the autopilot -> vehicle.cameraTriggerPoints)
    property int  _photoCount:      _haveVehicle && vehicle.cameraTriggerPoints ? vehicle.cameraTriggerPoints.count : 0
    property bool _photoFlash:      false
    property bool _photoBlinkOn:    false

    on_PhotoCountChanged: {
        if (_photoCount > 0) {
            _photoFlash = true
            _photoBlinkOn = true
            photoFlashTimer.restart()
            photoBlinkTimer.restart()
        }
    }

    Timer {
        id:         photoFlashTimer
        interval:   1500
        onTriggered: {
            control._photoFlash = false
            control._photoBlinkOn = false
            photoBlinkTimer.stop()
        }
    }

    Timer {
        id:         photoBlinkTimer
        interval:   250
        repeat:     true
        onTriggered: control._photoBlinkOn = !control._photoBlinkOn
    }

    FactPanelController { id: paramController }

    function _findEstopChannel() {
        if (!vehicle || !vehicle.parameterManager.parametersReady) {
            return 0
        }
        for (let i = 1; i <= 16; i++) {
            const name = "RC" + i + "_OPTION"
            if (paramController.parameterExists(-1, name)) {
                const fact = paramController.getParameterFact(-1, name, false)
                if (fact && fact.rawValue === 31) {
                    return i
                }
            }
        }
        return 0
    }

    function _channelOn(channel, threshold) {
        if (channel < 1 || channel > _rcChannels.length) {
            return false
        }
        const pwm = _rcChannels[channel - 1]
        return pwm > 0 && pwm < 3000 && pwm >= threshold
    }

    Connections {
        target: control.vehicle
        function onRcChannelsRawChanged(channelValues) { control._rcChannels = channelValues }
    }

    onVehicleChanged: {
        _rcChannels = []
        _estopEngaged = false
    }

    property real _margin:          ScreenTools.defaultFontPixelWidth * 0.75
    property bool _haveVehicle:     vehicle !== null && vehicle !== undefined
    property string _mode:          _haveVehicle ? vehicle.flightMode : ""

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Rectangle {
        anchors.fill:   parent
        color:          qgcPal.window
        radius:         ScreenTools.defaultFontPixelWidth / 2
        opacity:        0.75
    }

    ColumnLayout {
        id:                 mainLayout
        anchors.centerIn:   parent
        spacing:            ScreenTools.defaultFontPixelHeight * 0.4

        GidroLogHoldButton {
            Layout.fillWidth:   true
            text:               qsTr("ЗАПУСК")
            active:             control._haveVehicle && control.vehicle.armed
            activeColor:        "#F44336"
            enabled:            control._haveVehicle
            onActivated:        control.vehicle.armed = !control.vehicle.armed
        }

        // Motor emergency stop: MAV_CMD_DO_AUX_FUNCTION(218), aux function MOTOR_ESTOP(31),
        // switch level HIGH(2) = stop motors (vehicle stays armed), LOW(0) = release.
        GidroLogHoldButton {
            Layout.fillWidth:   true
            text:               control._estopEngaged ? qsTr("СНЯТЬ СТОП") : qsTr("СТОП")
            holdRequired:       control._estopEngaged      // engage instantly, release only with a 2 s hold
            blinking:           control._estopEngaged
            enabled:            control._haveVehicle
            onActivated: {
                const engage = !control._estopEngaged
                control.vehicle.sendCommand(1 /* MAV_COMP_ID_AUTOPILOT1 */, 218 /* MAV_CMD_DO_AUX_FUNCTION */, true,
                                            31 /* MOTOR_ESTOP */, engage ? 2 : 0 /* switch level HIGH / LOW */)
                control._estopEngaged = engage
            }
        }

        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: 1
            color:                  qgcPal.text
            opacity:                0.35
        }

        GidroLogHoldButton {
            Layout.fillWidth:   true
            text:               qsTr("РУЧНОЕ УПРАВЛЕНИЕ")
            active:             control._haveVehicle && control._mode === control.vehicle.stabilizedFlightMode
            enabled:            control._haveVehicle
            onActivated:        control.vehicle.flightMode = control.vehicle.stabilizedFlightMode
        }

        GidroLogHoldButton {
            Layout.fillWidth:   true
            text:               qsTr("ВЫПОЛНЕНИЕ ЗАДАНИЯ")
            active:             control._haveVehicle && control._mode === control.vehicle.missionFlightMode
            enabled:            control._haveVehicle
            onActivated:        control.vehicle.flightMode = control.vehicle.missionFlightMode
        }

        GidroLogHoldButton {
            Layout.fillWidth:   true
            text:               qsTr("УМНЫЙ ВОЗВРАТ")
            active:             control._haveVehicle && control._mode === control.vehicle.smartRTLFlightMode
            enabled:            control._haveVehicle
            onActivated:        control.vehicle.flightMode = control.vehicle.smartRTLFlightMode
        }

        GidroLogHoldButton {
            Layout.fillWidth:   true
            text:               qsTr("ВОЗВРАТ")
            active:             control._haveVehicle && control._mode === control.vehicle.rtlFlightMode
            enabled:            control._haveVehicle
            onActivated:        control.vehicle.flightMode = control.vehicle.rtlFlightMode
        }

        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: 1
            color:                  qgcPal.text
            opacity:                0.35
        }

        // Siren and beacon indicators
        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth

            Item { Layout.fillWidth: true }

            QGCColoredImage {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2
                Layout.preferredHeight: Layout.preferredWidth
                source:                 "/res/GidroLogSiren.svg"
                sourceSize.height:      height
                fillMode:               Image.PreserveAspectFit
                color:                  control.sirenActive ? "#F44336" : qgcPal.text   // GidroLog: siren on = red
                opacity:                control.sirenActive ? 1.0 : 0.5
            }

            Item { Layout.fillWidth: true }

            QGCColoredImage {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2
                Layout.preferredHeight: Layout.preferredWidth
                source:                 "/res/GidroLogBeacon.svg"
                sourceSize.height:      height
                fillMode:               Image.PreserveAspectFit
                color:                  control.beaconActive ? "#FF9800" : qgcPal.text
                opacity:                control.beaconActive ? 1.0 : 0.5
            }

            Item { Layout.fillWidth: true }

            // GidroLog: photo trigger (pin), blinks blue when a photo is taken
            QGCColoredImage {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2
                Layout.preferredHeight: Layout.preferredWidth
                source:                 "/res/GidroLogPhotoPin.svg"
                sourceSize.height:      height
                fillMode:               Image.PreserveAspectFit
                color:                  control._photoBlinkOn ? "#2196F3" : qgcPal.text
                opacity:                control._photoBlinkOn ? 1.0 : 0.5
            }

            Item { Layout.fillWidth: true }
        }
    }
}
