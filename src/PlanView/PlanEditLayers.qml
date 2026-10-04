pragma Singleton

import QtQuick

/// Single source of truth for the Plan View map editing layers. Used by the
/// layer switcher (PlanView), the plan tree view group headers, and the map
/// visual bindings.
QtObject {
    readonly property int layerMission: 1
    readonly property int layerFence:   2
    readonly property int layerRally:   3

    readonly property var layerInfos: [
        { layer: layerMission, nodeType: "missionGroup", icon: "/res/waypoint.svg",   name: qsTr("Задание") },
        { layer: layerFence,   nodeType: "fenceGroup",   icon: "/res/GeoFence.svg",   name: qsTr("Забор Безопасности") },
        { layer: layerRally,   nodeType: "rallyGroup",   icon: "/res/RallyPoint.svg", name: qsTr("Резервный порт") }
    ]

    function infoForNodeType(nodeType) {
        return layerInfos.find(l => l.nodeType === nodeType) ?? null
    }
}
