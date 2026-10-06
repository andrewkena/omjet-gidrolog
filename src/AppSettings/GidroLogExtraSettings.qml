import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// GidroLog: "Дополнительно" block on the General settings page.
// RC channels watched by the boat control panel: siren, beacon and motor emergency stop.
// Values are stored in mainWindow.gidroLogSettings (QtCore Settings, category "GidroLogControl").
SettingsGroupLayout {
    Layout.fillWidth:   true
    heading:            qsTr("Дополнительно")
    headingDescription: qsTr("Каналы пульта, которые отслеживает панель управления: сирена (красный значок), мигалка (оранжевый) и аварийная остановка моторов (кнопка СТОП)")

    property var _settings: mainWindow.gidroLogSettings

    // index 0 = "Не назначен" (0), 1..16 = channel
    property var _channelNames: {
        const names = [ qsTr("Не назначен") ]
        for (let i = 1; i <= 16; i++) {
            names.push(qsTr("Канал %1").arg(i))
        }
        return names
    }
    // index 0 = auto (-1), 1 = not assigned (0), 2..17 = channel 1..16
    property var _estopChannelNames: [ qsTr("Авто (RCx_OPTION = 31)") ].concat(_channelNames)

    Repeater {
        model: [
            { title: qsTr("Сирена"),                     channelKey: "sirenChannel",  thresholdKey: "sirenThreshold",  estop: false },
            { title: qsTr("Мигалка"),                    channelKey: "beaconChannel", thresholdKey: "beaconThreshold", estop: false },
            { title: qsTr("Аварийный стоп (Motor stop)"), channelKey: "estopChannel",  thresholdKey: "estopThreshold",  estop: true }
        ]

        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth

            QGCLabel {
                Layout.fillWidth:   true
                text:               modelData.title
            }

            QGCComboBox {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * (modelData.estop ? 22 : 16)
                model:                  modelData.estop ? _estopChannelNames : _channelNames
                currentIndex:           _settings ? (modelData.estop ? _settings[modelData.channelKey] + 1 : _settings[modelData.channelKey]) : 0
                onActivated: (index) => { _settings[modelData.channelKey] = modelData.estop ? index - 1 : index }
            }

            QGCLabel {
                text: qsTr("вкл. от, мкс")
            }

            QGCTextField {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8
                numericValuesOnly:      true
                text:                   _settings ? _settings[modelData.thresholdKey] : ""
                onEditingFinished: {
                    const v = parseInt(text)
                    if (!isNaN(v) && v >= 800 && v <= 2200) {
                        _settings[modelData.thresholdKey] = v
                    }
                    text = _settings[modelData.thresholdKey]
                }
            }
        }
    }

    QGCLabel {
        Layout.fillWidth:   true
        wrapMode:           Text.WordWrap
        font.pointSize:     ScreenTools.smallFontPointSize
        text:               qsTr("Аварийный стоп: «Авто» берёт канал, у которого на автопилоте RCx_OPTION = 31 (Motor Emergency Stop). Когда канал включён, кнопка СТОП на карте показывает «СНЯТЬ СТОП» и мигает; выключение канала снимает стоп и на кнопке.")
    }
}
