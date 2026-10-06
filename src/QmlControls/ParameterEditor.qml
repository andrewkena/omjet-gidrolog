import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id:         _root

    property Fact   _editorDialogFact: Fact { }
    property int    _rowHeight:         ScreenTools.defaultFontPixelHeight * 2
    property int    _rowWidth:          10 // Dynamic adjusted at runtime
    property bool   _searchFilter:      searchText.text.trim() != "" || controller.showModifiedOnly || controller.showFavoritesOnly  ///< true: showing results of search
    property var    _searchResults      ///< List of parameter names from search results
    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _showRCToParam:     _activeVehicle.px4Firmware
    property var    _appSettings:       QGroundControl.settingsManager.appSettings
    property var    _controller:        controller
    property var    _favorites:         controller.favoriteParameterNames
    property real   _margins:           ScreenTools.defaultFontPixelHeight / 2

    ParameterEditorController {
        id: controller
    }

    Timer {
        id:         clearTimer
        interval:   100;
        running:    false;
        repeat:     false
        onTriggered: {
            searchText.text = ""
            controller.searchText = ""
        }
    }

    QGCMenu {
        id:                 toolsMenu
        QGCMenuItem {
            text:           qsTr("Обновить")
            onTriggered:	controller.refresh()
        }
        QGCMenuItem {
            text:           qsTr("Сбросить всё к значениям прошивки")
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("Сбросить всё"),
                                                         qsTr("Нажмите «Сбросить», чтобы вернуть все параметры к значениям по умолчанию.\n\nБудет сброшено всё, включая узлы UAVCAN, настройки судна и калибровки."),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToDefaults() })
        }
        QGCMenuItem {
            text:           qsTr("Сбросить к значениям конфигурации судна")
            visible:        !_activeVehicle.apmFirmware
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("Сбросить всё"),
                                                         qsTr("Нажмите «Сбросить», чтобы вернуть все параметры к значениям конфигурации судна."),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToVehicleConfiguration() })
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            objectName:     "parameterEditor_toolLoadFromFile"
            text:           qsTr("Загрузить из файла для просмотра...")
            onTriggered: {
                fileDialog.title =          qsTr("Загрузка параметров")
                fileDialog.openForLoad()
            }
        }
        QGCMenuItem {
            text:           qsTr("Сохранить в файл...")
            onTriggered: {
                fileDialog.title =          qsTr("Сохранение параметров")
                fileDialog.openForSave()
            }
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Очистить избранное")
            onTriggered:    controller.clearAllFavorites()
        }
        QGCMenuSeparator { visible: _showRCToParam }
        QGCMenuItem {
            text:           qsTr("Очистить все привязки RC к параметрам")
            onTriggered:	_activeVehicle.clearAllParamMapRC()
            visible:        _showRCToParam
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Перезагрузить судно")
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("Перезагрузить судно"),
                                                         qsTr("Нажмите OK для перезагрузки судна."),
                                                         Dialog.Cancel | Dialog.Ok,
                                                         function() { _activeVehicle.rebootVehicle() })
        }
    }


    QGCFileDialog {
        id:             fileDialog
        folder:         _appSettings.parameterSavePath
        nameFilters:    [ qsTr("Файлы параметров (*.%1)").arg(_appSettings.parameterFileExtension), qsTr("Файлы Mission Planner (*.param)"), qsTr("Все файлы (*)") ]

        onAcceptedForSave: (file) => {
            controller.saveToFile(file)
            close()
        }

        onAcceptedForLoad: (file) => {
            close()
            if (controller.buildDiffFromFile(file)) {
                parameterDiffDialogFactory.open()
            }
        }
    }

    QGCPopupDialogFactory {
        id: editorDialogFactory

        dialogComponent: editorDialogComponent
    }

    Component {
        id: editorDialogComponent

        ParameterEditorDialog {
            fact:           _editorDialogFact
            showRCToParam:  _showRCToParam
        }
    }

    QGCPopupDialogFactory {
        id: parameterDiffDialogFactory

        dialogComponent: parameterDiffDialog
    }

    Component {
        id: parameterDiffDialog

        ParameterDiffDialog {
            paramController: _controller
        }
    }

    RowLayout {
        id:             header
        anchors.left:   parent.left
        anchors.right:  parent.right

        RowLayout {
            Layout.alignment:   Qt.AlignLeft
            spacing:            ScreenTools.defaultFontPixelWidth

            QGCTextField {
                id:                     searchText
                placeholderText:        qsTr("Поиск")
                onDisplayTextChanged:   controller.searchText = displayText
            }

            QGCButton {
                text: qsTr("Очистить")
                onClicked: {
                    if(ScreenTools.isMobile) {
                        Qt.inputMethod.hide();
                    }
                    clearTimer.start()
                }
            }

            QGCCheckBox {
                text:       qsTr("Скрыть только для чтения")
                checked:    controller.hideReadOnly
                onClicked:  controller.hideReadOnly = checked
            }
        }

        QGCButton {
            Layout.alignment:   Qt.AlignRight
            objectName:         "parameterEditor_toolsButton"
            text:               qsTr("Инструменты")
            onClicked:          toolsMenu.popup()
        }
    }

    QGCTabBar {
        id:             tabBar
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:        header.bottom
        anchors.topMargin:  _margins

        QGCTabButton { text: qsTr("Все") }
        QGCTabButton { text: qsTr("Изменённые") }
        QGCTabButton { text: qsTr("Избранное") }

        onCurrentIndexChanged: {
            controller.showModifiedOnly  = (currentIndex === 1)
            controller.showFavoritesOnly = (currentIndex === 2)
        }
    }

    /// Group buttons
    QGCFlickable {
        id :                groupScroll
        width:              ScreenTools.defaultFontPixelWidth * 25
        anchors.top:        tabBar.bottom
        anchors.topMargin:  _margins
        anchors.bottom:     parent.bottom
        clip:               true
        pixelAligned:       true
        contentHeight:      groupedViewCategoryColumn.height
        flickableDirection: Flickable.VerticalFlick
        visible:            !_searchFilter

        ColumnLayout {
            id:             groupedViewCategoryColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)

            Repeater {
                model: controller.categories

                Column {
                    Layout.fillWidth:   true
                    spacing:            Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)


                    SectionHeader {
                        id:             categoryHeader
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           object.name
                        checked:        object == controller.currentCategory

                        onCheckedChanged: {
                            if (checked) {
                                controller.currentCategory  = object
                            }
                        }
                    }

                    Repeater {
                        model: categoryHeader.checked ? object.groups : 0

                        QGCButton {
                            width:          ScreenTools.defaultFontPixelWidth * 25
                            text:           object.name
                            height:         _rowHeight
                            checked:        object == controller.currentGroup
                            autoExclusive:  true

                            onClicked: {
                                if (!checked) _rowWidth = 10
                                checked = true
                                controller.currentGroup = object
                            }
                        }
                    }
                }
            }
        }
    }

    HorizontalHeaderView {
        id:                 headerView
        anchors.left:       tableView.left
        anchors.right:      tableView.right
        anchors.top:        tabBar.bottom
        anchors.topMargin:  _margins
        syncView:           tableView
        clip:               true

        delegate: Rectangle {
            implicitWidth:  column === 0 ? ScreenTools.implicitCheckBoxHeight + ScreenTools.defaultFontPixelWidth
                                         : headerLabel.contentWidth + ScreenTools.defaultFontPixelWidth
            implicitHeight: headerLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.5
            color:          qgcPal.windowShade

            QGCLabel {
                id:                     headerLabel
                anchors.left:           parent.left
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                anchors.verticalCenter: parent.verticalCenter
                text:                   display
                font.bold:              true
            }

            // Top border
            Rectangle {
                anchors.top:    parent.top
                width:          parent.width
                height:         1
                color:          qgcPal.groupBorder
            }

            // Left border
            Rectangle {
                anchors.left:   parent.left
                height:         parent.height
                width:          1
                color:          qgcPal.groupBorder
            }

            // Right border (last column only)
            Rectangle {
                anchors.right:  parent.right
                height:         parent.height
                width:          1
                color:          qgcPal.groupBorder
                visible:        column == 3
            }

            // Bottom border
            Rectangle {
                anchors.bottom: parent.bottom
                width:          parent.width
                height:         1
                color:          qgcPal.groupBorder
            }
        }
    }

    TableView {
        id:                 tableView
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.top:        headerView.bottom
        anchors.bottom:     parent.bottom
        anchors.left:       _searchFilter ? parent.left : groupScroll.right
        anchors.right:      parent.right
        columnSpacing:      0
        rowSpacing:         0
        model:              controller.parameters
        contentWidth:       width
        clip:               true

        // Qt is supposed to adjust column widths automatically when larger widths come into view.
        // But it doesn't work. So we have to do it force a layout manually when we scroll.
        Timer {
            id:             forceLayoutTimer
            interval:       500
            repeat:         false
            onTriggered:    tableView.forceLayout()
        }

        onTopRowChanged: forceLayoutTimer.start()
        onModelChanged: {
            positionViewAtRow(0, TableView.AlignLeft | TableView.AlignTop)
            forceLayoutTimer.start()
        }

        delegate: Rectangle {
            implicitWidth:  column === 0 ? ScreenTools.implicitCheckBoxHeight + ScreenTools.defaultFontPixelWidth
                                         : column === 1 ? nameRow.implicitWidth + ScreenTools.defaultFontPixelWidth
                                         : column === 2 ? ScreenTools.defaultFontPixelWidth * 16
                                                        : label.contentWidth + ScreenTools.defaultFontPixelWidth
            implicitHeight: label.contentHeight + ScreenTools.defaultFontPixelHeight * 0.5
            color:          row % 2 === 0 ? "transparent" : qgcPal.windowShade
            clip:           true

            // Bottom grid line
            Rectangle {
                anchors.bottom: parent.bottom
                width:          parent.width
                height:         1
                color:          qgcPal.groupBorder
            }

            // Left grid line
            Rectangle {
                anchors.left:   parent.left
                height:         parent.height
                width:          1
                color:          qgcPal.groupBorder
            }

            // Right grid line (last column only)
            Rectangle {
                anchors.right:  parent.right
                height:         parent.height
                width:          1
                color:          qgcPal.groupBorder
                visible:        column == 3
            }

            QGCCheckBox {
                visible:                column === 0
                anchors.centerIn:       parent
                checked:                _root._favorites.indexOf(fact.name) >= 0
                z:                      1
                onClicked:              controller.toggleFavorite(fact.name)
            }

            Row {
                id:                     nameRow
                visible:                column === 1
                anchors.left:           parent.left
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                anchors.verticalCenter: parent.verticalCenter
                spacing:               lockIcon.visible ? ScreenTools.defaultFontPixelWidth / 3 : 0

                QGCLabel {
                    text:               column === 1 ? display : ""
                    anchors.verticalCenter: parent.verticalCenter
                }

                QGCColoredImage {
                    id:                 lockIcon
                    visible:            fact.readOnly
                    source:             "qrc:/InstrumentValueIcons/lock-closed.svg"
                    color:              qgcPal.text
                    width:              ScreenTools.defaultFontPixelHeight * 0.8
                    height:             width
                    sourceSize.width:   width
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            QGCLabel {
                id:                 label
                visible:            column !== 0 && column !== 1
                anchors.left:       parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth / 2
                anchors.verticalCenter: parent.verticalCenter
                width:              column == 2 ? ScreenTools.defaultFontPixelWidth * 15 : implicitWidth
                text:               column == 2 ? col1String() : display
                color:              column == 2 && fact.defaultValueAvailable && !fact.valueEqualsDefault ? qgcPal.modifiedParamValue : qgcPal.text
                font.bold:          column == 2 && fact.defaultValueAvailable && !fact.valueEqualsDefault
                maximumLineCount:   1
                elide:              column == 2 ? Text.ElideRight : Text.ElideNone

                function col1String() {
                    if (fact.enumStrings.length === 0) {
                        return fact.valueString + " " + fact.units
                    }
                    if (fact.bitmaskStrings.length != 0) {
                        return fact.selectedBitmaskStrings.join(',')
                    }
                    return fact.enumStringValue
                }
            }

            QGCMouseArea {
                anchors.fill: parent
                visible:      column !== 0
                onClicked: mouse => {
                    _editorDialogFact = fact
                    editorDialogFactory.open()
                }
            }
        }
    }
}
