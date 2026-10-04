#include "MockLinkBoatSim.h"
#include "MockLink.h"
#include "MAVLinkLib.h"

#include <QtCore/QDateTime>
#include <QtCore/QRandomGenerator>

#include <algorithm>
#include <cmath>
#include <cstring>

namespace {

constexpr double kEarthRadiusM = 6378137.0;
constexpr double kPi = 3.14159265358979323846;
constexpr double kDegToRad = kPi / 180.0;
constexpr double kRadToDeg = 180.0 / kPi;

double wrap180(double deg)
{
    while (deg > 180.0) {
        deg -= 360.0;
    }
    while (deg < -180.0) {
        deg += 360.0;
    }
    return deg;
}

bool isGlobalFrame(uint8_t frame)
{
    switch (frame) {
    case MAV_FRAME_GLOBAL:
    case MAV_FRAME_GLOBAL_RELATIVE_ALT:
    case MAV_FRAME_GLOBAL_INT:
    case MAV_FRAME_GLOBAL_RELATIVE_ALT_INT:
    case MAV_FRAME_GLOBAL_TERRAIN_ALT:
    case MAV_FRAME_GLOBAL_TERRAIN_ALT_INT:
        return true;
    default:
        return false;
    }
}

bool isNavCommand(uint16_t command)
{
    switch (command) {
    case MAV_CMD_NAV_WAYPOINT:
    case MAV_CMD_NAV_SPLINE_WAYPOINT:
    case MAV_CMD_NAV_LOITER_UNLIM:
    case MAV_CMD_NAV_LOITER_TURNS:
    case MAV_CMD_NAV_LOITER_TIME:
    case MAV_CMD_NAV_LOITER_TO_ALT:
        return true;
    default:
        return false;
    }
}

} // namespace

MockLinkBoatSim::MockLinkBoatSim(MockLink *mockLink)
    : _mockLink(mockLink)
    , _originLat(mockLink->_vehicleLatitude)
    , _originLon(mockLink->_vehicleLongitude)
{
}

double MockLinkBoatSim::bottomDepth(double northM, double eastM)
{
    // Synthetic lake bottom around the start point (x = east, y = north, metres):
    //   west shore at x = -120 m, bottom slopes down to the east,
    //   a deep hole NE of start, a shoal SW of start, a channel along x = +100 m, small ripples.
    const double x = eastM;
    const double y = northM;

    if (x <= -120.0) {
        return 0.0; // shore / dry land
    }

    double d = 0.3 + 0.045 * (x + 120.0);
    d += 5.0 * std::exp(-((x - 50.0) * (x - 50.0) + (y - 30.0) * (y - 30.0)) / (2.0 * 35.0 * 35.0));
    d -= 2.5 * std::exp(-((x + 30.0) * (x + 30.0) + (y + 60.0) * (y + 60.0)) / (2.0 * 25.0 * 25.0));
    d += 1.5 * std::exp(-((x - 100.0) * (x - 100.0)) / (2.0 * 20.0 * 20.0));
    d += 0.15 * std::sin(y / 12.0) * std::cos(x / 17.0);

    return std::clamp(d, 0.0, 30.0);
}

void MockLinkBoatSim::run10HzTasks()
{
    const uint32_t nowMs = static_cast<uint32_t>(_mockLink->_runningTime.elapsed());
    double dtSec = (_lastTickMs == 0) ? 0.1 : (nowMs - _lastTickMs) / 1000.0;
    dtSec = std::clamp(dtSec, 0.0, 0.5);
    _lastTickMs = nowMs;

    if (!_driverStartedSent) {
        _driverStartedSent = true;
        // "M36: драйвер запущен"
        _statusText(MAV_SEVERITY_INFO, QStringLiteral("M36: драйвер запущен"));
    }

    const bool armed = _mockLink->armed();
    const uint32_t mode = _mockLink->_mavCustomMode;

    // m36.lua: CSV opened on arm, closed on disarm
    if (armed && !_wasArmed) {
        const QDateTime utc = QDateTime::currentDateTimeUtc();
        _statusText(MAV_SEVERITY_INFO, QStringLiteral("M36: CSV APM/LOGS/M36_%1.CSV").arg(utc.toString(QStringLiteral("yyyyMMdd_HHmmss"))));
    } else if (!armed && _wasArmed) {
        // "M36: CSV закрыт"
        _statusText(MAV_SEVERITY_INFO, QStringLiteral("M36: CSV закрыт"));
    }
    _wasArmed = armed;

    // Mode handling
    if (armed && (mode == kModeAuto)) {
        if (!_autoActive) {
            _startMission();
        }
    } else {
        _autoActive = false;
    }

    if (armed && (mode == kModeRtl)) {
        _rtlActive = true;
    } else {
        _rtlActive = false;
    }

    if (_mockLink->_motorEStop) {
        // Motors stopped: the boat coasts to a halt, navigation does not progress
        _speedMS = std::max(0.0, _speedMS - 1.0 * dtSec);
        const double hdgRad = _headingDeg * kDegToRad;
        _northM += _speedMS * dtSec * std::cos(hdgRad);
        _eastM += _speedMS * dtSec * std::sin(hdgRad);
    } else {
        _updateMotion(dtSec);
    }
    _applyPosition();

    // Boat attitude: heading plus a little wave motion
    const double t = nowMs / 1000.0;
    _mockLink->setVehicleAttitudeOverrideDeg(static_cast<float>(1.5 * std::sin(t * 1.2)),
                                             static_cast<float>(0.8 * std::sin(t * 0.9)),
                                             static_cast<float>(_headingDeg));
    _sendVfrHud();

    if ((nowMs - _lastSensorMs) >= kPeriodMs) {
        _lastSensorMs = nowMs;
        _sensorUpdate(nowMs);
    }

    if ((nowMs - _last1HzMs) >= 1000) {
        _last1HzMs = nowMs;
        _sendMissionCurrent();
    }

    if (kDebugText && ((nowMs - _lastDebugMs) > 2000)) {
        _lastDebugMs = nowMs;
        _statusText(MAV_SEVERITY_INFO, QString::asprintf("M36 raw=%d T=%.2fC fails=%d", _lastRaw, static_cast<double>(_lastTempC), 0));
    }
}

void MockLinkBoatSim::_startMission()
{
    _nav.clear();
    _navIndex = -1;

    const auto &items = _mockLink->_missionItemHandler->_missionItems;
    _missionTotal = static_cast<uint16_t>(items.count());

    const double cosLat = std::cos(_originLat * kDegToRad);
    float pendingSpeed = 0;

    for (auto it = items.cbegin(); it != items.cend(); ++it) {
        if (it.key() == 0) {
            continue; // ArduPilot: item 0 is home
        }

        const mavlink_mission_item_int_t &item = it.value();

        if (item.command == MAV_CMD_DO_CHANGE_SPEED) {
            if (item.param2 > 0) {
                pendingSpeed = item.param2;
            }
            continue;
        }

        if (item.command == MAV_CMD_NAV_RETURN_TO_LAUNCH) {
            NavPoint p;
            p.seq = it.key();
            p.isRtl = true;
            p.speedMS = pendingSpeed;
            pendingSpeed = 0;
            _nav.append(p);
            continue;
        }

        if (!isNavCommand(item.command) || !isGlobalFrame(item.frame) || ((item.x == 0) && (item.y == 0))) {
            continue;
        }

        const double lat = item.x / 1e7;
        const double lon = item.y / 1e7;

        NavPoint p;
        p.seq = it.key();
        p.northM = (lat - _originLat) * kDegToRad * kEarthRadiusM;
        p.eastM = (lon - _originLon) * kDegToRad * kEarthRadiusM * cosLat;
        p.speedMS = pendingSpeed;
        pendingSpeed = 0;
        _nav.append(p);
    }

    if (_nav.isEmpty()) {
        _statusText(MAV_SEVERITY_WARNING, QStringLiteral("No Mission. Can't set AUTO."));
        _setMode(kModeHold);
        return;
    }

    _autoActive = true;
    _navIndex = 0;
    _missionCurrentSeq = _nav.first().seq;
    if (_nav.first().speedMS > 0) {
        _cruiseSpeedMS = _nav.first().speedMS;
    }
    _sendMissionCurrent();
}

void MockLinkBoatSim::_updateMotion(double dtSec)
{
    double targetNorth = 0;
    double targetEast = 0;
    bool haveTarget = false;

    if (_autoActive && (_navIndex >= 0) && (_navIndex < _nav.count())) {
        const NavPoint &p = _nav[_navIndex];
        targetNorth = p.isRtl ? 0.0 : p.northM;
        targetEast = p.isRtl ? 0.0 : p.eastM;
        haveTarget = true;
    } else if (_rtlActive) {
        haveTarget = true;
    }

    if (!haveTarget) {
        _speedMS = std::max(0.0, _speedMS - 1.0 * dtSec);
        return;
    }

    const double dn = targetNorth - _northM;
    const double de = targetEast - _eastM;
    const double dist = std::hypot(dn, de);

    if (dist <= kWaypointRadiusM) {
        if (_autoActive) {
            const NavPoint &reached = _nav[_navIndex];
            _sendMissionItemReached(reached.seq);

            if (reached.isRtl || (_navIndex + 1 >= _nav.count())) {
                _autoActive = false;
                _speedMS = 0;
                _statusText(MAV_SEVERITY_INFO, QStringLiteral("Mission Complete"));
                _setMode(kModeHold);
                return;
            }

            _navIndex++;
            _missionCurrentSeq = _nav[_navIndex].seq;
            if (_nav[_navIndex].speedMS > 0) {
                _cruiseSpeedMS = _nav[_navIndex].speedMS;
            }
            _sendMissionCurrent();
        } else {
            _rtlActive = false;
            _speedMS = 0;
            _statusText(MAV_SEVERITY_INFO, QStringLiteral("Reached destination"));
            _setMode(kModeHold);
        }
        return;
    }

    // Turn toward the target with a limited turn rate
    const double bearingDeg = std::atan2(de, dn) * kRadToDeg;
    _sendNavControllerOutput(bearingDeg, dist);
    const double turn = wrap180(bearingDeg - _headingDeg);
    const double maxTurn = kTurnRateDegS * dtSec;
    _headingDeg = wrap180(_headingDeg + std::clamp(turn, -maxTurn, maxTurn));

    // Accelerate to cruise speed, slow down when facing away from the target
    const double alignment = std::max(0.2, std::cos(turn * kDegToRad));
    const double targetSpeed = _cruiseSpeedMS * alignment;
    _speedMS += std::clamp(targetSpeed - _speedMS, -1.0 * dtSec, 0.5 * dtSec);

    const double step = std::min(_speedMS * dtSec, dist);
    const double hdgRad = _headingDeg * kDegToRad;
    _northM += step * std::cos(hdgRad);
    _eastM += step * std::sin(hdgRad);
}

void MockLinkBoatSim::_applyPosition()
{
    _mockLink->_vehicleLatitude = _originLat + (_northM / kEarthRadiusM) * kRadToDeg;
    _mockLink->_vehicleLongitude = _originLon + (_eastM / (kEarthRadiusM * std::cos(_originLat * kDegToRad))) * kRadToDeg;
}

void MockLinkBoatSim::_sensorUpdate(uint32_t nowMs)
{
    // What the M36 would measure here (+ a little noise)
    double depth = bottomDepth(_northM, _eastM) + (QRandomGenerator::global()->generateDouble() - 0.5) * 0.03;
    depth = std::max(0.0, depth);

    const int raw = std::clamp(static_cast<int>(std::lround(depth / kUnitM)), 0, 65535);

    // Water temperature: cooler with depth plus a slow drift, 0.01 degC resolution like the sensor
    const double t = nowMs / 1000.0;
    double tempC = 14.0 - 0.12 * depth + 0.25 * std::sin(2.0 * kPi * t / 300.0);
    tempC = std::round(tempC * 100.0) / 100.0;

    _lastRaw = raw;
    _lastTempC = static_cast<float>(tempC);

    // Same decisions as m36.lua update()
    const double d = raw * kUnitM;
    const bool valid = (raw != 0) && (d >= kMinM) && (d <= kMaxM);
    if (valid) {
        _sendDepthMessages(d, true, nowMs);
    } else if ((raw == 0) || (d < kMinM)) {
        _sendDepthMessages(kMinM * 0.5, false, nowMs); // OutOfRangeLow instead of No Data
    }

    _sendTemperature(_lastTempC, nowMs);
}

void MockLinkBoatSim::_sendDepthMessages(double distanceM, bool healthy, uint32_t nowMs)
{
    const uint8_t sysId = _mockLink->_vehicleSystemId;
    const uint8_t compId = MockLink::_vehicleComponentId;
    const uint8_t chan = _mockLink->_outgoingMavlinkChannel;

    // DISTANCE_SENSOR (RNGFND1: scripting backend, orientation down)
    {
        mavlink_distance_sensor_t ds{};
        ds.time_boot_ms = nowMs;
        ds.min_distance = static_cast<uint16_t>(kMinM * 100.0);
        ds.max_distance = static_cast<uint16_t>(kMaxM * 100.0);
        ds.current_distance = static_cast<uint16_t>(std::lround(distanceM * 100.0));
        ds.type = MAV_DISTANCE_SENSOR_UNKNOWN;
        ds.id = 0;
        ds.orientation = MAV_SENSOR_ROTATION_PITCH_270;
        ds.covariance = 0;

        mavlink_message_t msg{};
        (void) mavlink_msg_distance_sensor_encode_chan(sysId, compId, chan, &msg, &ds);
        _mockLink->respondWithMavlinkMessage(msg);
    }

    // RANGEFINDER (legacy ArduPilot message, downward rangefinder)
    {
        mavlink_rangefinder_t rf{};
        rf.distance = static_cast<float>(distanceM);
        rf.voltage = 0.0f;

        mavlink_message_t msg{};
        (void) mavlink_msg_rangefinder_encode_chan(sysId, compId, chan, &msg, &rf);
        _mockLink->respondWithMavlinkMessage(msg);
    }

    // WATER_DEPTH (ArduRover boat + downward rangefinder)
    {
        mavlink_water_depth_t wd{};
        wd.time_boot_ms = nowMs;
        wd.id = 0;
        wd.healthy = healthy ? 1 : 0;
        wd.lat = static_cast<int32_t>(std::lround(_mockLink->_vehicleLatitude * 1e7));
        wd.lng = static_cast<int32_t>(std::lround(_mockLink->_vehicleLongitude * 1e7));
        wd.alt = static_cast<float>(_mockLink->_vehicleAltitudeAMSL);
        wd.roll = 0.0f;
        wd.pitch = 0.0f;
        wd.yaw = static_cast<float>(_headingDeg * kDegToRad);
        wd.distance = static_cast<float>(distanceM);
        wd.temperature = 0.0f; // scripting rangefinder backend has no temperature; M36 temp comes via M36TEMP

        mavlink_message_t msg{};
        (void) mavlink_msg_water_depth_encode_chan(sysId, compId, chan, &msg, &wd);
        _mockLink->respondWithMavlinkMessage(msg);
    }
}

void MockLinkBoatSim::_sendTemperature(float tempC, uint32_t nowMs)
{
    // NAMED_VALUE_FLOAT.name is a fixed 10-byte field
    mavlink_named_value_float_t nv{};
    nv.time_boot_ms = nowMs;
    nv.value = tempC;
    static constexpr char kName[] = "M36TEMP";
    (void) std::memcpy(nv.name, kName, sizeof(kName));

    mavlink_message_t msg{};
    (void) mavlink_msg_named_value_float_encode_chan(_mockLink->_vehicleSystemId, MockLink::_vehicleComponentId, _mockLink->_outgoingMavlinkChannel, &msg, &nv);
    _mockLink->respondWithMavlinkMessage(msg);
}

void MockLinkBoatSim::_sendVfrHud()
{
    mavlink_vfr_hud_t hud{};
    hud.airspeed = static_cast<float>(_speedMS);
    hud.groundspeed = static_cast<float>(_speedMS);
    hud.heading = static_cast<int16_t>(std::lround(_headingDeg + 360.0) % 360);
    hud.throttle = (_speedMS > 0.05) ? static_cast<uint16_t>(std::clamp(_speedMS / 4.0 * 100.0, 5.0, 100.0)) : 0;
    hud.alt = static_cast<float>(_mockLink->_vehicleAltitudeAMSL);
    hud.climb = 0.0f;

    mavlink_message_t msg{};
    (void) mavlink_msg_vfr_hud_encode_chan(_mockLink->_vehicleSystemId, MockLink::_vehicleComponentId, _mockLink->_outgoingMavlinkChannel, &msg, &hud);
    _mockLink->respondWithMavlinkMessage(msg);
}

void MockLinkBoatSim::_sendMissionCurrent()
{
    if (_missionTotal == 0) {
        return;
    }

    mavlink_mission_current_t mc{};
    mc.seq = _missionCurrentSeq;
    mc.total = _missionTotal;
    mc.mission_state = _autoActive ? MISSION_STATE_ACTIVE : MISSION_STATE_NOT_STARTED;
    mc.mission_mode = _autoActive ? 1 : 0;

    mavlink_message_t msg{};
    (void) mavlink_msg_mission_current_encode_chan(_mockLink->_vehicleSystemId, MockLink::_vehicleComponentId, _mockLink->_outgoingMavlinkChannel, &msg, &mc);
    _mockLink->respondWithMavlinkMessage(msg);
}

void MockLinkBoatSim::_sendMissionItemReached(uint16_t seq)
{
    mavlink_mission_item_reached_t reached{};
    reached.seq = seq;

    mavlink_message_t msg{};
    (void) mavlink_msg_mission_item_reached_encode_chan(_mockLink->_vehicleSystemId, MockLink::_vehicleComponentId, _mockLink->_outgoingMavlinkChannel, &msg, &reached);
    _mockLink->respondWithMavlinkMessage(msg);
}

void MockLinkBoatSim::_sendNavControllerOutput(double bearingDeg, double distM)
{
    // Like ArduRover: desired course to the target and distance to it
    mavlink_nav_controller_output_t nav{};
    nav.nav_roll = 0.0f;
    nav.nav_pitch = 0.0f;
    nav.nav_bearing = static_cast<int16_t>(std::lround(bearingDeg));
    nav.target_bearing = static_cast<int16_t>(std::lround(bearingDeg));
    nav.wp_dist = static_cast<uint16_t>(std::clamp(distM, 0.0, 65535.0));
    nav.alt_error = 0.0f;
    nav.aspd_error = 0.0f;
    nav.xtrack_error = 0.0f;

    mavlink_message_t msg{};
    (void) mavlink_msg_nav_controller_output_encode_chan(_mockLink->_vehicleSystemId, MockLink::_vehicleComponentId, _mockLink->_outgoingMavlinkChannel, &msg, &nav);
    _mockLink->respondWithMavlinkMessage(msg);
}

void MockLinkBoatSim::_setMode(uint32_t customMode)
{
    _mockLink->_mavCustomMode = customMode;
}

void MockLinkBoatSim::_statusText(uint8_t severity, const QString &text)
{
    _mockLink->sendStatusTextMessage(severity, text);
}
