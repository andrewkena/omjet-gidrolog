import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

ToolIndicatorPage {
    id:         control
    showExpand: true

    property var    linkConfigs:            QGroundControl.linkManager.linkConfigurations
    property bool   noLinks:                true
    property var    editingConfig:          null
    property var    autoConnectSettings:    QGroundControl.settingsManager.autoConnectSettings

    Component.onCompleted: {
        for (var i = 0; i < linkConfigs.count; i++) {
            var linkConfig = linkConfigs.get(i)
            if (!linkConfig.dynamic && !linkConfig.isAutoConnect) {
                noLinks = false
                break
            }
        }
    }

    contentComponent: Component {
        SettingsGroupLayout {
            heading: qsTr("Выберите канал связи")

            QGCLabel {
                text:       qsTr("Каналы связи не настроены")
                visible:    noLinks
            }

            Repeater {
                model: linkConfigs

                delegate: QGCButton {
                    Layout.fillWidth:   true
                    text:               object.name + (object.link ? " (" + qsTr("подключено") + ")" : "")
                    visible:            !object.dynamic
                    enabled:            !object.link
                    autoExclusive:      true

                    onClicked: {
                        QGroundControl.linkManager.createConnectedLink(object)
                        mainWindow.closeIndicatorDrawer()
                    }
                }
            }
        }
    }

    expandedComponent: Component {
        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            SettingsGroupLayout {
                LabelledButton {
                    label:      qsTr("Каналы связи")
                    buttonText: qsTr("Настроить")

                    onClicked: {
                        // Untranslated page key from SettingsPages.json — do not qsTr()
                        mainWindow.showSettingsTool("Comm Links")
                        mainWindow.closeIndicatorDrawer()
                    }
                }
            }

            SettingsGroupLayout {
                heading:        qsTr("Автоподключение")
                visible:        autoConnectSettings.userVisible

                Repeater {
                    id: autoConnectRepeater

                    model: [
                        autoConnectSettings.autoConnectPixhawk,
                        autoConnectSettings.autoConnectSiKRadio,
                        autoConnectSettings.autoConnectLibrePilot,
                        autoConnectSettings.autoConnectUDP,
                        autoConnectSettings.autoConnectRTKGPS,
                    ]

                    property var names: [ qsTr("Pixhawk"), qsTr("Радиомодем SiK"), qsTr("LibrePilot"), qsTr("UDP"), qsTr("RTK") ]

                    FactCheckBoxSlider {
                        Layout.fillWidth:   true
                        text:               autoConnectRepeater.names[index]
                        fact:               modelData
                        visible:            modelData.visible
                    }
                }
            }
        }
    }
}
