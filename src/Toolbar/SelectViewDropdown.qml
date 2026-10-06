import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ToolIndicatorPage {
    id: root

    property real _toolButtonHeight: ScreenTools.defaultFontPixelHeight * 3

    contentComponent: Component {
        GridLayout {
            columns: 2
            columnSpacing: ScreenTools.defaultFontPixelWidth
            rowSpacing: columnSpacing

            SubMenuButton {
                objectName: "toolbar_viewFly"
                implicitHeight: root._toolButtonHeight
                Layout.fillWidth: true
                text: qsTr("КАРТА")
                imageResource: "/res/GidroLogMenuMap.svg"
                imageOriginalColors: true
                onClicked: {
                    if (mainWindow.allowViewSwitch()) {
                        mainWindow.closeIndicatorDrawer()
                        mainWindow.showFlyView()
                    }
                }
            }

            SubMenuButton {
                objectName: "toolbar_viewPlan"
                implicitHeight: root._toolButtonHeight
                Layout.fillWidth: true
                text: qsTr("ЗАДАНИЕ")
                imageResource: "/res/GidroLogMenuPlan.svg"
                imageOriginalColors: true
                onClicked: {
                    if (mainWindow.allowViewSwitch()) {
                        mainWindow.closeIndicatorDrawer()
                        mainWindow.showPlanView()
                    }
                }
            }

            SubMenuButton {
                objectName: "toolbar_viewAnalyze"
                implicitHeight: root._toolButtonHeight
                Layout.fillWidth: true
                text: qsTr("АНАЛИЗ")
                imageResource: "/res/GidroLogMenuAnalyze.svg"
                imageOriginalColors: true
                visible: QGroundControl.corePlugin.showAdvancedUI
                onClicked: {
                    if (mainWindow.allowViewSwitch()) {
                        mainWindow.closeIndicatorDrawer()
                        mainWindow.showAnalyzeTool()
                    }
                }
            }

            SubMenuButton {
                id: setupButton
                objectName: "toolbar_viewConfigure"
                implicitHeight: root._toolButtonHeight
                Layout.fillWidth: true
                text: qsTr("ПАРАМЕТРЫ СУДНА")
                imageResource: "/res/GidroLogMenuVessel.svg"
                imageOriginalColors: true
                onClicked: {
                    if (mainWindow.allowViewSwitch()) {
                        mainWindow.closeIndicatorDrawer()
                        mainWindow.showVehicleConfig()
                    }
                }
            }

            SubMenuButton {
                id: settingsButton
                objectName: "toolbar_viewSettings"
                implicitHeight: root._toolButtonHeight
                Layout.fillWidth: true
                text: qsTr("НАСТРОЙКИ ПРОГРАММЫ")
                imageResource: "/res/GidroLogMenuSettings.svg"
                imageOriginalColors: true
                visible: !QGroundControl.corePlugin.options.combineSettingsAndSetup
                onClicked: {
                    if (mainWindow.allowViewSwitch()) {
                        mainWindow.closeIndicatorDrawer()
                        mainWindow.showSettingsTool()
                    }
                }
            }

            SubMenuButton {
                id: closeButton
                objectName: "toolbar_viewClose"
                implicitHeight: root._toolButtonHeight
                Layout.fillWidth: true
                text: qsTr("ВЫХОД")
                imageResource: "/res/GidroLogMenuExit.svg"
                imageOriginalColors: true
                onClicked: {
                    if (mainWindow.allowViewSwitch()) {
                        mainWindow.closeIndicatorDrawer()
                        // Route through the window close handler so the unsaved
                        // mission / pending parameter / active connection checks
                        // run, matching the desktop window-close behavior.
                        mainWindow.close()
                    }
                }
            }

            ColumnLayout {
                id: versionColumnLayout
                Layout.fillWidth: true
                Layout.columnSpan: 2
                spacing: 0

                QGCButton {
                    objectName: "toolbar_updateButton"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: ScreenTools.defaultFontPixelHeight / 2
                    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
                    heightFactor: 0.2
                    leftPadding: ScreenTools.defaultFontPixelWidth
                    rightPadding: leftPadding
                    text: qsTr("Обновление")
                    primary: true
                    pointSize: ScreenTools.smallFontPointSize
                    visible: QGroundControl.newStableVersion !== ""
                    onClicked: {
                        mainWindow.closeIndicatorDrawer()
                        Qt.openUrlExternally(QGroundControl.corePlugin.stableDownloadUrl)
                    }
                }

                QGCLabel {
                    id: versionLabel
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    // GidroLog: version as in the window title, then author, then build date
                    text: "ОМДЖЕТ ГидроЛог " + Qt.application.version.replace(/^v/, "")
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode: QGCLabel.WordWrap
                }

                QGCLabel {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Andrew Kena"
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode: QGCLabel.WrapAnywhere
                }

                QGCLabel {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    // "2026-10-01T02:34:14+0000" -> "01.10.2026"
                    text: {
                        const d = String(QGroundControl.qgcAppDate).substring(0, 10).split("-")
                        return d.length === 3 ? d[2] + "." + d[1] + "." + d[0] : QGroundControl.qgcAppDate
                    }
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode: QGCLabel.WrapAnywhere

                    QGCMouseArea {
                        anchors.topMargin: -(parent.y - versionLabel.y)
                        anchors.fill: parent

                        onClicked: (mouse) => {
                            if (mouse.modifiers & Qt.ControlModifier) {
                                QGroundControl.corePlugin.showTouchAreas = !QGroundControl.corePlugin.showTouchAreas
                                showTouchAreasNotification.open()
                            } else if (ScreenTools.isMobile || mouse.modifiers & Qt.ShiftModifier) {
                                mainWindow.closeIndicatorDrawer()
                                if (!QGroundControl.corePlugin.showAdvancedUI) {
                                    advancedModeOnConfirmation.open()
                                } else {
                                    advancedModeOffConfirmation.open()
                                }
                            }
                        }

                        // This allows you to change this on mobile
                        onPressAndHold: {
                            QGroundControl.corePlugin.showTouchAreas = !QGroundControl.corePlugin.showTouchAreas
                            showTouchAreasNotification.open()
                        }
                    }
                }
            }
        }
    }
}
