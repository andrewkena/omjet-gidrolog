import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// GidroLog: "Дополнительно" block on the General settings page.
// RC channels for the siren and beacon indicators on the boat control panel.
// Values are stored in mainWindow.gidroLogSettings (QtCore Settings, category "GidroLogControl").
SettingsGroupLayout {
    Layout.fillWidth:   true
    heading:            qsTr("Дополнительно")
    headingDescription: qsTr("Каналы RC, по которым индикаторы сирены и мигалки на панели управления становятся красными")

    property var _settings: mainWindow.gidroLogSettings
    property var _channelNames: {
        const names = [ qsTr("Не назначен") ]
        for (let i = 1; i <= 16; i++) {
            names.push(qsTr("Канал %1").arg(i))
        }
        return names
    }

    Repeater {
        model: [
            { title: qsTr("Сирена"),  channelKey: "sirenChannel",  thresholdKey: "sirenThreshold" },
            { title: qsTr("Мигалка"), channelKey: "beaconChannel", thresholdKey: "beaconThreshold" }
        ]

        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth

            QGCLabel {
                Layout.fillWidth:   true
                text:               modelData.title
            }

            QGCComboBox {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 16
                model:                  _channelNames
                currentIndex:           _settings ? _settings[modelData.channelKey] : 0
                onActivated: (index) => { _settings[modelData.channelKey] = index }
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
}
