import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// GidroLog: right-edge survey panel (top to bottom): speed, distance travelled, water temperature, depth.
// Clicking a value opens a dialog where colour ranges for that value are set (stored in QSettings).
Item {
    id:             control
    implicitWidth:  _contentWidth + (_margin * 2)
    implicitHeight: mainLayout.implicitHeight + (_margin * 2)

    property var  vehicle:          QGroundControl.multiVehicleManager.activeVehicle
    property var  _sounder:         vehicle ? vehicle.getFactGroup("sounder") : null
    property real _margin:          ScreenTools.defaultFontPixelWidth * 0.75
    property real _valueFontSize:   ScreenTools.largeFontPointSize * 2  // digits: 2x the previous size
    property real _unitsFontSize:   ScreenTools.largeFontPointSize      // units: unchanged
    property real _minContentWidth: ScreenTools.defaultFontPixelWidth * 16
    property real _contentWidth:    Math.max(mainLayout.implicitWidth, _minContentWidth)

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // ---- Colour ranges -------------------------------------------------------------------------
    readonly property var _swatches: [ "#4CAF50", "#FFD54F", "#FF9800", "#F44336", "#29B6F6", "#FFFFFF" ]

    // One JSON string per value: { enabled, ranges: [ { on, from, to, color } x3 ] }
    Settings {
        id:             valueColorSettings
        category:       "GidroLogValueColors"
        property string speed:      ""
        property string distance:   ""
        property string temp:       ""
        property string depth:      ""
    }

    property var _rules: ({
        speed:      _parseRules(valueColorSettings.speed),
        distance:   _parseRules(valueColorSettings.distance),
        temp:       _parseRules(valueColorSettings.temp),
        depth:      _parseRules(valueColorSettings.depth)
    })

    function _defaultRules() {
        return { enabled: false, ranges: [
            { on: false, from: "", to: "", color: "#4CAF50" },
            { on: false, from: "", to: "", color: "#FFD54F" },
            { on: false, from: "", to: "", color: "#F44336" } ] }
    }

    function _parseRules(json) {
        const def = _defaultRules()
        if (!json) {
            return def
        }
        try {
            const r = JSON.parse(json)
            if (!r || !Array.isArray(r.ranges)) {
                return def
            }
            for (let i = 0; i < 3; i++) {
                if (r.ranges[i]) {
                    def.ranges[i] = r.ranges[i]
                }
            }
            def.enabled = !!r.enabled
            return def
        } catch (e) {
            return def
        }
    }

    function _toNumber(text, fallback) {
        const s = String(text === undefined || text === null ? "" : text).trim().replace(",", ".")
        if (s === "") {
            return fallback
        }
        const v = parseFloat(s)
        return isNaN(v) ? fallback : v
    }

    // Colour from the first matching enabled range (from <= value < to), "" if none
    function _ruleColor(kind, fact) {
        const rules = _rules[kind]
        if (!rules || !rules.enabled || !fact) {
            return ""
        }
        const v = Number(fact.value)
        if (isNaN(v)) {
            return ""
        }
        for (let i = 0; i < rules.ranges.length; i++) {
            const r = rules.ranges[i]
            if (!r.on) {
                continue
            }
            if (v >= _toNumber(r.from, -Infinity) && v < _toNumber(r.to, Infinity)) {
                return r.color
            }
        }
        return ""
    }

    // Grey backing
    Rectangle {
        id:             backing
        anchors.fill:   parent
        color:          qgcPal.window
        radius:         ScreenTools.defaultFontPixelWidth / 2
        opacity:        0.75
    }

    ColumnLayout {
        id:                         mainLayout
        anchors.horizontalCenter:   backing.horizontalCenter
        anchors.verticalCenter:     backing.verticalCenter
        width:                      control._contentWidth
        spacing:                    ScreenTools.defaultFontPixelHeight * 0.4

        Repeater {
            model: [
                { label: qsTr("Скорость"),    fact: control.vehicle ? control.vehicle.groundSpeed : null,    kind: "speed" },
                { label: qsTr("Пройдено"),    fact: control.vehicle ? control.vehicle.flightDistance : null, kind: "distance" },
                { label: qsTr("Температура"), fact: control._sounder ? control._sounder.waterTemp : null,    kind: "temp" },
                { label: qsTr("Глубина"),     fact: control._sounder ? control._sounder.depth : null,        kind: "depth" }
            ]

            ColumnLayout {
                id:                 valueItem
                Layout.fillWidth:   true
                spacing:            ScreenTools.defaultFontPixelHeight * 0.4

                property var  fact:     modelData.fact
                property var  parts:    control._valueParts(fact, modelData.kind)
                property bool warning:  modelData.kind === "depth" && control._sounder && fact && !isNaN(fact.rawValue) && control._sounder.depthHealthy.rawValue === 0
                property string ruleColor: control._ruleColor(modelData.kind, fact)

                // Horizontal separator between values
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 1
                    color:                  qgcPal.text
                    opacity:                0.35
                    visible:                index > 0
                }

                // Caption, centered on the backing
                QGCLabel {
                    Layout.fillWidth:       true
                    horizontalAlignment:    Text.AlignHCenter
                    text:                   modelData.label
                    font.pointSize:         ScreenTools.smallFontPointSize
                }

                // Value + units, centered as one group on the backing
                Item {
                    Layout.fillWidth:       true
                    implicitWidth:          valueRow.implicitWidth
                    implicitHeight:         valueRow.implicitHeight

                    Row {
                        id:                         valueRow
                        anchors.horizontalCenter:   parent.horizontalCenter
                        spacing:                    ScreenTools.defaultFontPixelWidth * 0.4

                        QGCLabel {
                            id:                 valueLabel
                            text:               valueItem.parts.value
                            font.pointSize:     control._valueFontSize
                            font.weight:        Font.Black
                            color:              valueItem.warning ? qgcPal.colorOrange : (valueItem.ruleColor !== "" ? valueItem.ruleColor : qgcPal.text)
                        }

                        QGCLabel {
                            anchors.baseline:   valueLabel.baseline
                            text:               valueItem.parts.units
                            visible:            text !== ""
                            font.pointSize:     control._unitsFontSize
                            font.bold:          true
                            color:              valueLabel.color
                        }
                    }
                }

                // Click on the caption or value opens the colour dialog for this value
                Item {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 0
                    MouseArea {
                        x:              0
                        y:              -valueItem.height
                        width:          parent.width
                        height:         valueItem.height
                        cursorShape:    Qt.PointingHandCursor
                        onClicked:      colorPopup.openFor(modelData.kind, modelData.label,
                                                           valueItem.fact ? control.cyrillicUnits(valueItem.fact.units) : "")
                    }
                }
            }
        }
    }

    // ---- Colour dialog ---------------------------------------------------------------------------
    Popup {
        id:             colorPopup
        parent:         Overlay.overlay
        modal:          true
        focus:          true
        x:              Math.round((parent.width - width) / 2)
        y:              Math.round((parent.height - height) / 2)
        padding:        ScreenTools.defaultFontPixelWidth * 1.5
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string kind:   ""
        property string title:  ""
        property string units:  ""

        function openFor(kind, title, units) {
            colorPopup.kind = kind
            colorPopup.title = title
            colorPopup.units = units
            const rules = control._rules[kind]
            enabledBox.checked = rules.enabled
            for (let i = 0; i < 3; i++) {
                rowRepeater.itemAt(i).load(rules.ranges[i])
            }
            open()
        }

        function save() {
            const ranges = []
            for (let i = 0; i < 3; i++) {
                ranges.push(rowRepeater.itemAt(i).read())
            }
            valueColorSettings[colorPopup.kind] = JSON.stringify({ enabled: enabledBox.checked, ranges: ranges })
            close()
        }

        background: Rectangle {
            color:          qgcPal.window
            radius:         ScreenTools.defaultFontPixelWidth / 2
            border.color:   qgcPal.text
            border.width:   1
        }

        contentItem: ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight * 0.5

            QGCLabel {
                text:           qsTr("%1 — цвет значения").arg(colorPopup.title)
                font.bold:      true
                font.pointSize: ScreenTools.mediumFontPointSize
            }

            QGCCheckBox {
                id:     enabledBox
                text:   qsTr("Раскрашивать по диапазонам")
            }

            Repeater {
                id:     rowRepeater
                model:  3

                RowLayout {
                    id:         rangeRow
                    spacing:    ScreenTools.defaultFontPixelWidth
                    enabled:    enabledBox.checked
                    opacity:    enabled ? 1 : 0.5

                    property string selColor: control._swatches[0]

                    function load(r) {
                        onBox.checked = !!r.on
                        fromField.text = r.from !== undefined ? String(r.from) : ""
                        toField.text = r.to !== undefined ? String(r.to) : ""
                        selColor = r.color ? r.color : control._swatches[0]
                    }

                    function read() {
                        return {
                            on:     onBox.checked,
                            from:   fromField.text.trim().replace(",", "."),
                            to:     toField.text.trim().replace(",", "."),
                            color:  selColor
                        }
                    }

                    QGCCheckBox { id: onBox }

                    QGCLabel { text: qsTr("от") }
                    QGCTextField {
                        id:                     fromField
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 7
                        enabled:                onBox.checked
                    }

                    QGCLabel { text: qsTr("до") }
                    QGCTextField {
                        id:                     toField
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 7
                        enabled:                onBox.checked
                    }

                    QGCLabel { text: colorPopup.units }

                    Row {
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        enabled: onBox.checked

                        Repeater {
                            model: control._swatches

                            Rectangle {
                                width:          ScreenTools.defaultFontPixelHeight * 1.3
                                height:         width
                                radius:         width / 5
                                color:          modelData
                                border.width:   rangeRow.selColor === modelData ? 3 : 1
                                border.color:   rangeRow.selColor === modelData ? qgcPal.text : "#555555"

                                MouseArea {
                                    anchors.fill:   parent
                                    onClicked:      rangeRow.selColor = modelData
                                }
                            }
                        }
                    }
                }
            }

            QGCLabel {
                Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 60
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.smallFontPointSize
                text:                   qsTr("Цвет берётся из первого подходящего диапазона (от ≤ значение < до). Пустое поле — без ограничения. Если ни один диапазон не подошёл — обычный цвет.")
            }

            RowLayout {
                Layout.alignment:   Qt.AlignRight
                spacing:            ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text:       qsTr("Отмена")
                    onClicked:  colorPopup.close()
                }

                QGCButton {
                    text:       qsTr("Сохранить")
                    primary:    true
                    onClicked:  colorPopup.save()
                }
            }
        }
    }

    // Returns { value, units } for display
    function _valueParts(fact, kind) {
        if (!fact) {
            return { value: "--", units: "" }
        }
        const raw = fact.rawValue
        if (raw === undefined || raw === null || isNaN(raw)) {
            return { value: "--", units: "" }
        }
        const units = fact.units
        // Distance: switch to km past 1000 m when user units are metres
        if (kind === "distance" && units === "m" && fact.value >= 1000) {
            return { value: (fact.value / 1000).toFixed(2), units: cyrillicUnits("km") }
        }
        return { value: fact.valueString, units: cyrillicUnits(units) }
    }

    // GidroLog: unit names in Cyrillic
    function cyrillicUnits(units) {
        const map = {
            "m":    "м",
            "km":   "км",
            "m/s":  "м/с",
            "km/h": "км/ч",
            "kn":   "уз",
            "ft":   "фт",
            "ft/s": "фт/с",
            "mi":   "миль",
            "mph":  "миль/ч",
            "C":    "°C",
            "F":    "°F"
        }
        return map[units] !== undefined ? map[units] : units
    }
}
