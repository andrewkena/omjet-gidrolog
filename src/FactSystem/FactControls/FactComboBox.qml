import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

QGCComboBox {
    property Fact fact: Fact { }
    property bool indexModel: fact ? fact.enumValues.length === 0 : true // true: Fact values are indices, false: Fact values are FactMetadata.enumValues

    model: fact ? _gidroLogTranslate(fact.enumStrings) : null

    // GidroLog: Russian names for common enum values (failsafe actions, display options, ...).
    // Mode names keep the original in brackets so they match the toolbar / autopilot.
    readonly property var _gidroLogEnumRu: ({
        "Warn only":                "Только предупреждение",
        "Warn Only":                "Только предупреждение",
        "RTL":                      "Возврат (RTL)",
        "Hold":                     "Удержание (Hold)",
        "SmartRTL":                 "Умный возврат (SmartRTL)",
        "SmartRTL or RTL":          "Умный возврат или возврат",
        "SmartRTL or Hold":         "Умный возврат или удержание",
        "RTL or Hold":              "Возврат или удержание",
        "Hold or RTL":              "Удержание или возврат",
        "Terminate":                "Аварийное завершение",
        "Loiter or Hold":           "Кружение или удержание",
        "Loiter":                   "Кружение (Loiter)",
        "Land":                     "Посадка",
        "Disarm":                   "Остановить моторы",
        "None":                     "Нет",
        "Disabled":                 "Отключено",
        "Enabled":                  "Включено",
        "Percentage":               "Проценты",
        "Voltage":                  "Напряжение",
        "Percentage and Voltage":   "Проценты и напряжение",
        "Always":                   "Всегда",
        "Never":                    "Никогда",
        "Auto":                     "Авто",
        "Manual":                   "Ручной (Manual)",
        "Acro":                     "Акро (Acro)",
        "Steering":                 "Рулевой (Steering)",
        "Guided":                   "Ведомый (Guided)",
        "Follow":                   "Следование (Follow)",
        "Simple":                   "Простой (Simple)",
        "Dock":                     "Причаливание (Dock)",
        "Circle":                   "Круг (Circle)"
    })

    function _gidroLogTranslate(list) {
        const out = []
        for (let i = 0; i < list.length; i++) {
            const s = list[i]
            out.push(_gidroLogEnumRu[s] !== undefined ? _gidroLogEnumRu[s] : s)
        }
        return out
    }

    currentIndex: fact ? (indexModel ? fact.value : fact.enumIndex) : 0

    function _updateCurrentIndex() {
        Qt.callLater(function() {
            currentIndex = Qt.binding(function() {
                return fact ? (indexModel ? fact.value : fact.enumIndex) : 0
            })
        })
    }

    onModelChanged: {
        // When the model changes, the index gets reset to 0, so re-establish
        // the declarative currentIndex binding. callLater() avoids a binding
        // loop since enumIndex could trigger a model change.
        _updateCurrentIndex()
    }

    onFactChanged: {
        // When the fact changes to a different Fact object with the same
        // enumStrings, modelChanged does not fire, so the binding must be
        // re-established here to point at the new Fact.
        _updateCurrentIndex()
    }

    onActivated: (index) => {
        if (indexModel) {
            fact.value = index
        } else {
            fact.value = fact.enumValues[index]
        }
    }
}
