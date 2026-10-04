import QtCore
import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.PlanView

FlightMap {
    id:                         _root
    allowGCSLocationCenter:     true
    allowVehicleLocationCenter: !_keepVehicleCentered
    planView:                   false
    zoomLevel:                  QGroundControl.flightMapZoom
    center:                     QGroundControl.flightMapPosition

    property Item   pipView
    property Item   pipState:                   _pipState
    property var    rightPanelWidth
    property var    planMasterController
    property bool   pipMode:                    false   // true: map is shown in a small pip mode
    property var    toolInsets                          // Insets for the center viewport area
    property alias  depthColorSettings:         depthColorSettings  // GidroLog: shared with the legend in FlyViewWidgetLayer

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _planMasterController:      planMasterController
    property var    _geoFenceController:        planMasterController.geoFenceController
    property var    _rallyPointController:      planMasterController.rallyPointController
    property var    _activeVehicleCoordinate:   _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()
    property real   _toolButtonTopMargin:       parent.height - mainWindow.height + (ScreenTools.defaultFontPixelHeight / 2)
    property real   _toolsMargin:               ScreenTools.defaultFontPixelWidth * 0.75
    property var    _flyViewSettings:           QGroundControl.settingsManager.flyViewSettings
    property bool   _keepMapCenteredOnVehicle:  _flyViewSettings.keepMapCenteredOnVehicle.rawValue

    property bool   _keepVehicleCentered:       pipMode ? true : false
    property bool   _saveZoomLevelSetting:      true

    function _adjustMapZoomForPipMode() {
        _saveZoomLevelSetting = false
        if (pipMode) {
            if (QGroundControl.flightMapZoom > 3) {
                zoomLevel = QGroundControl.flightMapZoom - 3
            }
        } else {
            zoomLevel = QGroundControl.flightMapZoom
        }
        _saveZoomLevelSetting = true
    }

    onPipModeChanged: _adjustMapZoomForPipMode()

    onVisibleChanged: {
        if (visible) {
            // Synchronize center position with Plan View
            center = QGroundControl.flightMapPosition
        }
    }

    onZoomLevelChanged: {
        if (_saveZoomLevelSetting) {
            QGroundControl.flightMapZoom = _root.zoomLevel
        }
    }
    onCenterChanged: {
        QGroundControl.flightMapPosition = _root.center
    }

    // We track whether the user has panned or not to correctly handle automatic map positioning
    onMapPanStart:  positionTracker.userInteracting = true
    onMapPanStop:   positionTracker.userInteracting = false

    // Follow behavior on top of FlightMap's one-shot centering: hard follow while
    // the keep-centered setting or pip mode is active, inset-rect follow otherwise
    Binding {
        target: positionTracker
        property: "keepVehicleCentered"
        value: _keepMapCenteredOnVehicle || _keepVehicleCentered
    }

    Binding {
        target: positionTracker
        property: "animating"
        value: animateLat.running || animateLong.running
    }

    Connections {
        target: positionTracker
        function onRecenterVehicleTo(screenPoint) {
            // Move the map such that the vehicle lands on screenPoint
            let vehiclePoint = _root.fromCoordinate(_activeVehicleCoordinate, false /* clipToViewport */)
            let centerOffset = Qt.point((_root.width / 2) - screenPoint.x, (_root.height / 2) - screenPoint.y)
            let vehicleOffsetPoint = Qt.point(vehiclePoint.x + centerOffset.x, vehiclePoint.y + centerOffset.y)
            let vehicleOffsetCoord = _root.toCoordinate(vehicleOffsetPoint, false /* clipToViewport */)
            animatedMapRecenter(_root.center, vehicleOffsetCoord)
        }
    }

    property real _animatedLatitudeStart
    property real _animatedLatitudeStop
    property real _animatedLongitudeStart
    property real _animatedLongitudeStop
    property real animatedLatitude
    property real animatedLongitude

    onAnimatedLatitudeChanged: _root.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)
    onAnimatedLongitudeChanged: _root.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)

    NumberAnimation on animatedLatitude { id: animateLat; from: _animatedLatitudeStart; to: _animatedLatitudeStop; duration: 1000 }
    NumberAnimation on animatedLongitude { id: animateLong; from: _animatedLongitudeStart; to: _animatedLongitudeStop; duration: 1000 }

    function animatedMapRecenter(fromCoord, toCoord) {
        _animatedLatitudeStart = fromCoord.latitude
        _animatedLongitudeStart = fromCoord.longitude
        _animatedLatitudeStop = toCoord.latitude
        _animatedLongitudeStop = toCoord.longitude
        animateLat.start()
        animateLong.start()
    }

    // returns the rectangle formed by the four center insets
    // used for checking if vehicle is under ui, and as a target for recentering the view
    function _insetCenterRect() {
        return Qt.rect(toolInsets.leftEdgeCenterInset,
                       toolInsets.topEdgeCenterInset,
                       _root.width - toolInsets.leftEdgeCenterInset - toolInsets.rightEdgeCenterInset,
                       _root.height - toolInsets.topEdgeCenterInset - toolInsets.bottomEdgeCenterInset)
    }

    // returns the four rectangles formed by the 8 corner insets
    // used for detecting if the vehicle has flown under the instrument panel, virtual joystick etc
    function _insetCornerRects() {
        return [
            Qt.rect(0,0,
                    toolInsets.leftEdgeTopInset,
                    toolInsets.topEdgeLeftInset),
            Qt.rect(_root.width-toolInsets.rightEdgeTopInset,0,
                    toolInsets.rightEdgeTopInset,
                    toolInsets.topEdgeRightInset),
            Qt.rect(0,_root.height-toolInsets.bottomEdgeLeftInset,
                    toolInsets.leftEdgeBottomInset,
                    toolInsets.bottomEdgeLeftInset),
            Qt.rect(_root.width-toolInsets.rightEdgeBottomInset,_root.height-toolInsets.bottomEdgeRightInset,
                    toolInsets.rightEdgeBottomInset,
                    toolInsets.bottomEdgeRightInset)]
    }

    PipState {
        id:         _pipState
        pipView:    _root.pipView
        isDark:     _isFullWindowItemDark
    }

    Timer {
        interval:       500
        running:        true
        repeat:         true
        onTriggered: {
            let vehiclePoint = _root.fromCoordinate(_activeVehicleCoordinate, false /* clipToViewport */)
            positionTracker.evaluateInsetFollow(vehiclePoint, _insetCenterRect(), _insetCornerRects())
        }
    }

    QGCMapPalette { id: mapPal; lightColors: isSatelliteMap }

    Connections {
        target:                 _missionController
        ignoreUnknownSignals:   true
        function onNewItemsFromVehicle() {
            var visualItems = _missionController.visualItems
            if (visualItems && visualItems.count !== 1) {
                mapFitFunctions.fitMapViewportToMissionItems()
                firstVehiclePositionReceived = true
            }
        }
    }

    MapFitFunctions {
        id:                         mapFitFunctions // The name for this id cannot be changed without breaking references outside of this code. Beware!
        map:                        _root
        usePlannedHomePosition:     false
        planMasterController:       _planMasterController
    }

    ObstacleDistanceOverlayMap {
        id: obstacleDistance
        mapControl: _root
        showText: !pipMode
    }

    // Add trajectory lines to the map
    MapPolyline {
        id:         trajectoryPolyline
        line.width: 3
        line.color: "red"
        z:          QGroundControl.zOrderTrajectoryLines
        visible:    false   // GidroLog: replaced by the depth-colored track below

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                trajectoryPolyline.path = _activeVehicle ? _activeVehicle.trajectoryPoints.list() : []
            }
        }

        Connections {
            target:                             _activeVehicle ? _activeVehicle.trajectoryPoints : null
            function onPointAdded(coordinate) { trajectoryPolyline.addCoordinate(coordinate) }
            function onUpdateLastPoint(coordinate) { trajectoryPolyline.replaceCoordinate(trajectoryPolyline.pathLength() - 1, coordinate) }
            function onPointsCleared() { trajectoryPolyline.path = [] }
        }
    }

    // GidroLog: depth markers on the track - a point every N s (legend slider, default 10) with the echo sounder depth next to it.
    // Recorded while armed (same as the track), cleared together with the track.
    ListModel {
        id: depthMarkersModel
    }

    Timer {
        interval:   Math.min(depthColorSettings.markerIntervalSec, 60) * 1000
        repeat:     true
        running:    (_activeVehicle ? _activeVehicle.armed : false) && depthColorSettings.markerIntervalSec <= 60   // > 60 = labels off
        onTriggered: {
            const sounder = _activeVehicle.getFactGroup("sounder")
            const coord = _activeVehicle.coordinate
            if (!sounder || !coord.isValid) {
                return
            }
            const depth = sounder.depth.rawValue
            if (depth === undefined || depth === null || isNaN(depth)) {
                return
            }
            depthMarkersModel.append({
                lat:        coord.latitude,
                lon:        coord.longitude,
                depthText:  sounder.depth.valueString + " " + (sounder.depth.units === "m" ? "м" : (sounder.depth.units === "ft" ? "фт" : sounder.depth.units)),
                healthy:    sounder.depthHealthy.rawValue !== 0
            })
        }
    }

    Connections {
        target:                     _activeVehicle ? _activeVehicle.trajectoryPoints : null
        function onPointsCleared()  { depthMarkersModel.clear(); depthTrack.clear() }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) { depthMarkersModel.clear(); depthTrack.clear() }
    }

    MapItemView {
        model: depthMarkersModel

        delegate: MapQuickItem {
            coordinate:     QtPositioning.coordinate(model.lat, model.lon)
            anchorPoint.x:  depthDot.width / 2
            anchorPoint.y:  depthDot.height / 2
            z:              QGroundControl.zOrderTrajectoryLines + 1
            visible:        !pipMode

            sourceItem: Item {
                width:  depthDot.width
                height: depthDot.height

                Rectangle {
                    id:             depthDot
                    width:          ScreenTools.defaultFontPixelHeight * 0.6
                    height:         width
                    radius:         width / 2
                    color:          model.healthy ? "yellow" : "orange"
                    border.color:   "black"
                    border.width:   1
                }

                QGCLabel {
                    anchors.left:           depthDot.right
                    anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 0.3
                    anchors.verticalCenter: depthDot.verticalCenter
                    text:                   model.depthText
                    visible:                _root.zoomLevel >= 17 && depthColorSettings.markerIntervalSec <= 60
                    color:                  "white"
                    style:                  Text.Outline
                    styleColor:             "black"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    font.bold:              true
                }
            }
        }
    }

    // GidroLog: live depth map (Lowrance-style) - grid of soundings with IDW gap filling,
    // colored with the same scale as the track, drawn under the track as raster tiles
    property var _depthGrid: {
        const sounder = _activeVehicle ? _activeVehicle.getFactGroup("sounder") : null
        return sounder ? sounder.depthGrid : null
    }

    // Zoom level at which one tile pixel is exactly one grid cell (MapQuickItem scales relative to it)
    property real _depthGridTileZoom: {
        const deps = [ zoomLevel, width, height, center ]
        if (!_depthGrid || width <= 0 || height <= 0) {
            return zoomLevel
        }
        const c1 = toCoordinate(Qt.point(width / 2, height / 2), false)
        const c2 = toCoordinate(Qt.point(width / 2 + 100, height / 2), false)
        const metersPerPixel = c1.distanceTo(c2) / 100
        return metersPerPixel > 0 ? zoomLevel + Math.log2(metersPerPixel / _depthGrid.cellSize) : zoomLevel
    }

    Binding {
        target:     _depthGrid
        property:   "depthMin"
        value:      depthColorSettings.depthMin
        when:       _depthGrid !== null
    }

    Binding {
        target:     _depthGrid
        property:   "depthMax"
        value:      depthColorSettings.depthMax
        when:       _depthGrid !== null
    }

    MapItemView {
        model: _depthGrid && depthColorSettings.showDepthMap ? _depthGrid.tiles : []

        delegate: MapQuickItem {
            coordinate:     QtPositioning.coordinate(modelData.lat, modelData.lon)
            anchorPoint.x:  0
            anchorPoint.y:  0
            zoomLevel:      _root._depthGridTileZoom
            z:              QGroundControl.zOrderTrajectoryLines - 1
            opacity:        depthColorSettings.depthMapOpacity
            visible:        !_root.pipMode

            sourceItem: DepthGridTile {
                width:  _root._depthGrid ? _root._depthGrid.tileSize : 256
                height: width
                grid:   _root._depthGrid
                tileX:  modelData.tx
                tileY:  modelData.ty
                smooth: true
            }
        }
    }

    // GidroLog: depth-colored track (replaces the red trajectory line).
    // Sampled every second while armed, gradient from red (shallow, <= min) to blue (deep, >= max),
    // grey where the echo sounder gives no depth. Min/max are set in the legend and remembered.
    Settings {
        id:         depthColorSettings
        category:   "GidroLogDepthColors"

        property real depthMin: 0
        property real depthMax: 10
        property int  markerIntervalSec: 10     // depth label interval, set by the legend slider
        property bool showDepthMap: true        // live depth map overlay on/off (legend button)
        property real depthMapOpacity: 0.6

        onDepthMinChanged: depthTrack.rebuild()
        onDepthMaxChanged: depthTrack.rebuild()
    }

    function depthGradientColor(t) {
        const stops = [ [0.00, 1, 0, 0],    // red
                        [0.25, 1, 1, 0],    // yellow
                        [0.50, 0, 1, 0],    // green
                        [0.75, 0, 1, 1],    // cyan
                        [1.00, 0, 0, 1] ]   // blue
        for (let i = 1; i < stops.length; i++) {
            if (t <= stops[i][0]) {
                const a = stops[i - 1]
                const b = stops[i]
                const f = (t - a[0]) / (b[0] - a[0])
                return Qt.rgba(a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, 1)
            }
        }
        return Qt.rgba(0, 0, 1, 1)
    }

    Component {
        id: depthSegmentComponent

        MapPolyline {
            line.width: 4
            z:          QGroundControl.zOrderTrajectoryLines
            visible:    !_root.pipMode
        }
    }

    QtObject {
        id: depthTrack

        property var    points:         []      // [{ coord, depth }] - kept for recoloring
        property var    segments:       []      // MapPolyline items, one per run of equal color
        property var    currentSegment: null
        property int    currentKey:     -2
        property var    lastCoord:      null
        readonly property int levels:   24      // color steps between min and max

        function colorKey(depth) {
            if (depth === undefined || depth === null || isNaN(depth)) {
                return -1
            }
            const range = Math.max(0.01, depthColorSettings.depthMax - depthColorSettings.depthMin)
            const t = Math.min(1, Math.max(0, (depth - depthColorSettings.depthMin) / range))
            return Math.round(t * (levels - 1))
        }

        function colorForKey(key) {
            return key < 0 ? "#9e9e9e" : _root.depthGradientColor(key / (levels - 1))
        }

        function clearSegments() {
            for (let i = 0; i < segments.length; i++) {
                _root.removeMapItem(segments[i])
                segments[i].destroy()
            }
            segments = []
            currentSegment = null
            currentKey = -2
            lastCoord = null
        }

        function clear() {
            clearSegments()
            points = []
        }

        function addPoint(coord, depth, store) {
            if (store) {
                points.push({ coord: coord, depth: depth })
            }
            const key = colorKey(depth)
            if (!currentSegment || key !== currentKey) {
                const segment = depthSegmentComponent.createObject(_root)
                segment.line.color = colorForKey(key)
                segment.path = lastCoord ? [ lastCoord, coord ] : [ coord ]
                _root.addMapItem(segment)
                segments.push(segment)
                currentSegment = segment
                currentKey = key
            } else {
                currentSegment.addCoordinate(coord)
            }
            lastCoord = coord
        }

        function rebuild() {
            clearSegments()
            for (let i = 0; i < points.length; i++) {
                addPoint(points[i].coord, points[i].depth, false)
            }
        }
    }

    Timer {
        interval:   1000
        repeat:     true
        running:    _activeVehicle ? _activeVehicle.armed : false
        onTriggered: {
            const coord = _activeVehicle.coordinate
            if (!coord.isValid) {
                return
            }
            if (depthTrack.lastCoord && depthTrack.lastCoord.distanceTo(coord) < 1.0) {
                return  // not moving
            }
            const sounder = _activeVehicle.getFactGroup("sounder")
            const depth = sounder ? sounder.depth.rawValue : NaN
            depthTrack.addPoint(QtPositioning.coordinate(coord.latitude, coord.longitude), depth, true)
        }
    }

    // Legend (min/max, label interval) is GidroLogDepthLegend in FlyViewWidgetLayer

    // GidroLog: course lines in front of the boat
    //   orange - current heading (fixed on-screen length)
    //   blue   - commanded course to the current target point (ends at the point)
    MapQuickItem {
        id:             headingLineItem
        coordinate:     _activeVehicleCoordinate
        anchorPoint.x:  headingLine.width / 2
        anchorPoint.y:  headingLine.height
        z:              QGroundControl.zOrderVehicles - 1
        visible:        !pipMode && _activeVehicle && _activeVehicleCoordinate.isValid && !isNaN(_activeVehicle.heading.rawValue)

        sourceItem: Rectangle {
            id:         headingLine
            width:      2
            height:     ScreenTools.defaultFontPixelHeight * 8
            color:      "#FF9800"
            antialiasing: true

            transform: Rotation {
                origin.x:   headingLine.width / 2
                origin.y:   headingLine.height
                angle:      (_activeVehicle ? _activeVehicle.heading.rawValue : 0) - _root.bearing
            }
        }
    }

    MapPolyline {
        id:             courseToTargetLine
        line.width:     2
        line.color:     "#00B0FF"   // GidroLog: light blue - course to the current mission point
        z:              QGroundControl.zOrderVehicles - 1
        visible:        !pipMode && _targetLineValid
        path:           _targetLineValid ? [ _activeVehicleCoordinate, _activeVehicleCoordinate.atDistanceAndAzimuth(_targetDistance, _targetBearing) ] : []

        property real _targetBearing:   _activeVehicle ? _activeVehicle.headingToNextWP.rawValue : NaN
        property real _targetDistance:  _activeVehicle ? _activeVehicle.distanceToNextWP.rawValue : NaN
        property bool _targetLineValid: _activeVehicle && _activeVehicle.armed && _activeVehicleCoordinate.isValid && !isNaN(_targetBearing) && !isNaN(_targetDistance) && _targetDistance > 0
    }

    // Add the vehicles to the map
    MapItemView {
        model: QGroundControl.multiVehicleManager.vehicles
        delegate: VehicleMapItem {
            vehicle:        object
            coordinate:     object.coordinate
            map:            _root
            size:           pipMode ? ScreenTools.defaultFontPixelHeight : ScreenTools.defaultFontPixelHeight * 3
            z:              QGroundControl.zOrderVehicles
        }
    }
    // Add distance sensor view
    MapItemView{
        model: QGroundControl.multiVehicleManager.vehicles
        delegate: ProximityRadarMapView {
            vehicle:        object
            coordinate:     object.coordinate
            map:            _root
            z:              QGroundControl.zOrderVehicles
        }
    }
    // Add ADSB vehicles to the map
    MapItemView {
        model: QGroundControl.adsbVehicleManager.adsbVehicles
        delegate: ADSBVehicleMapItem {
            coordinate:     object.coordinate
            altitude:       object.altitude
            callsign:       object.callsign
            heading:        object.heading
            alert:          object.alert
            map:            _root
            size:           pipMode ? ScreenTools.defaultFontPixelHeight : ScreenTools.defaultFontPixelHeight * 2.5
            z:              QGroundControl.zOrderVehicles
        }
    }

    // Add the items associated with each vehicles flight plan to the map
    Repeater {
        model: QGroundControl.multiVehicleManager.vehicles

        PlanMapItems {
            map:                    _root
            largeMapView:           !pipMode
            planMasterController:   masterController
            vehicle:                _vehicle

            property var _vehicle: object

            PlanMasterController {
                id: masterController
                Component.onCompleted: startStaticActiveVehicle(object)
            }
        }
    }

    // Allow custom builds to add map items
    CustomMapItems {
        map:            _root
        largeMapView:   !pipMode
    }

    GeoFenceMapVisuals {
        map:                    _root
        myGeoFenceController:   _geoFenceController
        interactive:            false
        planView:               false
        homePosition:           _activeVehicle && _activeVehicle.homePosition.isValid ? _activeVehicle.homePosition :  QtPositioning.coordinate()
    }

    // Rally points on map
    MapItemView {
        model: _rallyPointController.points

        delegate: MapQuickItem {
            id:             itemIndicator
            anchorPoint.x:  sourceItem.anchorPointX
            anchorPoint.y:  sourceItem.anchorPointY
            coordinate:     object.coordinate
            z:              QGroundControl.zOrderMapItems

            sourceItem: MissionItemIndexLabel {
                id:         itemIndexLabel
                label:      qsTr("R", "rally point map item label")
            }
        }
    }

    // Camera trigger points
    MapItemView {
        model: _activeVehicle ? _activeVehicle.cameraTriggerPoints : 0

        delegate: CameraTriggerIndicator {
            coordinate:     object.coordinate
            z:              QGroundControl.zOrderTopMost
        }
    }

    // GoTo Location forward flight circle visuals
    QGCMapCircleVisuals {
        id:                 fwdFlightGotoMapCircle
        mapControl:         parent
        mapCircle:          _fwdFlightGotoMapCircle
        radiusLabelVisible: true
        // PX4 ignores the commanded loiter radius (flies NAV_LOITER_RAD), so the circle size is unknown
        visible:            gotoLocationItem.visible && _activeVehicle &&
                            !_activeVehicle.px4Firmware &&
                            _activeVehicle.inFwdFlight &&
                            !_activeVehicle.orbitActive

        property alias coordinate: _fwdFlightGotoMapCircle.center
        property alias radius: _fwdFlightGotoMapCircle.radius
        property alias clockwiseRotation: _fwdFlightGotoMapCircle.clockwiseRotation

        Component.onCompleted: {
            // Only allow editing the radius, not the position
            centerDragHandleVisible = false

            globals.guidedControllerFlyView.fwdFlightGotoMapCircle = this
        }

        Binding {
            target: _fwdFlightGotoMapCircle
            property: "center"
            value: gotoLocationItem.coordinate
        }

        function startLoiterRadiusEdit() {
            _fwdFlightGotoMapCircle.interactive = true
        }

        // Called when loiter edit is confirmed
        function actionConfirmed() {
            _fwdFlightGotoMapCircle.interactive = false
            _fwdFlightGotoMapCircle._commitRadius()
        }

        // Called when loiter edit is cancelled
        function actionCancelled() {
            _fwdFlightGotoMapCircle.interactive = false
            _fwdFlightGotoMapCircle._restoreRadius()
        }

        QGCMapCircle {
            id:                 _fwdFlightGotoMapCircle
            interactive:        false
            showRotation:       true
            clockwiseRotation:  true

            property real _defaultLoiterRadius: _flyViewSettings.forwardFlightGoToLocationLoiterRad.rawValue
            property real _committedRadius;

            onCenterChanged: {
                radius.rawValue = _defaultLoiterRadius
                // Don't commit the radius in case this operation is undone
            }

            Component.onCompleted: {
                radius.rawValue = _defaultLoiterRadius
                _commitRadius()
            }

            function _commitRadius() {
                _committedRadius = radius.rawValue
            }

            function _restoreRadius() {
                radius.rawValue = _committedRadius
            }
        }
    }

    // GoTo Location visuals
    MapQuickItem {
        id:             gotoLocationItem
        visible:        false
        z:              QGroundControl.zOrderMapItems
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY
        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("Go here", "Go to location waypoint")
        }

        property bool inGotoFlightMode: _activeVehicle ? _activeVehicle.flightMode === _activeVehicle.gotoFlightMode : false

        property var _committedCoordinate: null

        onInGotoFlightModeChanged: {
            if (!inGotoFlightMode && gotoLocationItem.visible) {
                // Hide goto indicator when vehicle falls out of guided mode
                hide()
            }
        }

        function show(coord) {
            gotoLocationItem.coordinate = coord
            gotoLocationItem.visible = true
        }

        function hide() {
            gotoLocationItem.visible = false
        }

        function actionConfirmed() {
            _commitCoordinate()

            // Commit the new radius which possibly changed
            fwdFlightGotoMapCircle.actionConfirmed()

            // We leave the indicator visible. The handling for onInGuidedModeChanged will hide it.
        }

        function actionCancelled() {
            _restoreCoordinate()

            // Also restore the loiter radius
            fwdFlightGotoMapCircle.actionCancelled()
        }

        function _commitCoordinate() {
            // Must deep copy
            _committedCoordinate = QtPositioning.coordinate(
                coordinate.latitude,
                coordinate.longitude
            );
        }

        function _restoreCoordinate() {
            if (_committedCoordinate) {
                coordinate = _committedCoordinate
            } else {
                hide()
            }
        }
    }

    // Orbit editing visuals
    QGCMapCircleVisuals {
        id:             orbitMapCircle
        mapControl:     parent
        mapCircle:      _mapCircle
        visible:        false

        property alias center:              _mapCircle.center
        property alias clockwiseRotation:   _mapCircle.clockwiseRotation
        readonly property real defaultRadius: 30

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                if (!activeVehicle) {
                    orbitMapCircle.visible = false
                }
            }
        }

        function show(coord) {
            _mapCircle.radius.rawValue = defaultRadius
            orbitMapCircle.center = coord
            orbitMapCircle.visible = true
        }

        function hide() {
            orbitMapCircle.visible = false
        }

        function actionConfirmed() {
            // Live orbit status is handled by telemetry so we hide here and telemetry will show again.
            hide()
        }

        function actionCancelled() {
            hide()
        }

        function radius() {
            return _mapCircle.radius.rawValue
        }

        Component.onCompleted: globals.guidedControllerFlyView.orbitMapCircle = orbitMapCircle

        QGCMapCircle {
            id:                 _mapCircle
            interactive:        true
            radius.rawValue:    30
            showRotation:       true
            clockwiseRotation:  true
        }
    }

    // ROI Location visuals
    MapQuickItem {
        id:             roiLocationItem
        visible:        _activeVehicle && _activeVehicle.isROIEnabled
        z:              QGroundControl.zOrderMapItems
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY

        Connections {
            target: _activeVehicle
            function onRoiCoordChanged(centerCoord) {
                roiLocationItem.show(centerCoord)
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: (position) => {
                position = Qt.point(position.x, position.y)
                var clickCoord = _root.toCoordinate(position, false /* clipToViewPort */)
                // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
                position = mapToItem(globals.parent, position)
                var dropPanel = roiEditDropPanelComponent.createObject(mainWindow, { clickRect: Qt.rect(position.x, position.y, 0, 0) })
                dropPanel.open()
            }
        }

        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("ROI here", "Make this a Region Of Interest")
        }

        //-- Visibilty controlled by actual state
        function show(coord) {
            roiLocationItem.coordinate = coord
        }
    }

    // Orbit telemetry visuals
    QGCMapCircleVisuals {
        id:             orbitTelemetryCircle
        mapControl:     parent
        mapCircle:      _activeVehicle ? _activeVehicle.orbitMapCircle : null
        visible:        _activeVehicle ? _activeVehicle.orbitActive : false
    }

    MapQuickItem {
        id:             orbitCenterIndicator
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY
        coordinate:     _activeVehicle ? _activeVehicle.orbitMapCircle.center : QtPositioning.coordinate()
        visible:        orbitTelemetryCircle.visible && !gotoLocationItem.visible

        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("Orbit", "Orbit waypoint")
        }
    }

    QGCPopupDialogFactory {
        id: roiEditPositionDialogFactory

        dialogComponent: roiEditPositionDialogComponent
    }

    Component {
        id: roiEditPositionDialogComponent

        EditPositionDialog {
            title:                  qsTr("Edit ROI Position")
            coordinate:             roiLocationItem.coordinate

            readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

            // The ROI belongs to the vehicle the dialog was opened for; close
            // if that vehicle goes away or the active vehicle changes
            on_ActiveVehicleChanged: close()

            onCoordinateChanged: {
                roiLocationItem.coordinate = coordinate
                _activeVehicle.guidedModeROI(coordinate, _activeVehicle.roiRelativeAltitudeMeters)
            }
        }
    }

    Component {
        id: roiEditDropPanelComponent

        DropPanel {
            id: roiEditDropPanel

            readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

            // The ROI belongs to the vehicle the panel was opened for; close
            // if that vehicle goes away or the active vehicle changes
            on_ActiveVehicleChanged: close()

            // Created dynamically per ROI click; close() alone would leak the panel
            onClosed: destroy()

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelWidth / 2

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Cancel ROI")
                        onClicked: {
                            _activeVehicle.stopGuidedModeROI()
                            roiEditDropPanel.close()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Edit Position")
                        onClicked: {
                            roiEditPositionDialogFactory.open()
                            roiEditDropPanel.close()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mapClickDropPanelComponent

        FlyViewMapClickDropPanel {
            gotoIndicator:  gotoLocationItem
            orbitIndicator: orbitMapCircle
        }
    }

    onMapClicked: (position) => {
        if (!globals.guidedControllerFlyView.guidedUIVisible &&
            (globals.guidedControllerFlyView.showGotoLocation || globals.guidedControllerFlyView.showOrbit ||
             globals.guidedControllerFlyView.showROI || globals.guidedControllerFlyView.showSetHome ||
             globals.guidedControllerFlyView.showSetEstimatorOrigin)) {

            position = Qt.point(position.x, position.y)
            var clickCoord = _root.toCoordinate(position, false /* clipToViewPort */)
            // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
            position = _root.mapToItem(globals.parent, position)
            var dropPanel = mapClickDropPanelComponent.createObject(mainWindow, { mapClickCoord: clickCoord, clickRect: Qt.rect(position.x, position.y, 0, 0) })
            dropPanel.open()
        }
    }

    MapScale {
        id:                 mapScale
        anchors.margins:    _toolsMargin
        anchors.left:       parent.left
        anchors.top:        parent.top
        mapControl:         _root
        visible:            !ScreenTools.isTinyScreen && QGroundControl.corePlugin.options.flyView.showMapScale && mapControl.pipState.state === mapControl.pipState.windowState
    }
}
