#pragma once

// GidroLog: simulated survey boat for MockLink.
//
// Emulates an ArduRover boat carrying a Dayu M36 echo sounder read by APM/scripts/m36.lua:
//   - boat drives the uploaded mission in AUTO, returns home in RTL, stops in HOLD at the end
//   - synthetic lake bottom gives depth as a function of the boat position
//   - sends what the real Cube sends for the sounder:
//       DISTANCE_SENSOR / RANGEFINDER / WATER_DEPTH  (rangefinder scripting backend, RNGFND1_TYPE=36, ORIENT=25)
//       NAMED_VALUE_FLOAT "M36TEMP"                  (water temperature, gcs:send_named_float)
//       STATUSTEXT "M36: ..."                         (driver messages, DEBUG text every 2 s)
//
// Only active for ArduPilot Rover MockLink ("APM ArduRover Vehicle"). Debug builds only (MockLink).

#include <QtCore/QList>
#include <QtCore/QString>

#include <cstdint>

class MockLink;

class MockLinkBoatSim
{
public:
    explicit MockLinkBoatSim(MockLink *mockLink);

    /// Called from MockLink::run10HzTasks on the MockLink worker thread
    void run10HzTasks();

    /// Depth of the synthetic bottom (metres) at a local offset from the start point
    static double bottomDepth(double northM, double eastM);

private:
    struct NavPoint {
        uint16_t seq = 0;
        double northM = 0;
        double eastM = 0;
        bool isRtl = false;
        float speedMS = 0;
    };

    void _startMission();
    void _updateMotion(double dtSec);
    void _sensorUpdate(uint32_t nowMs);
    void _sendVfrHud();
    void _sendMissionCurrent();
    void _sendMissionItemReached(uint16_t seq);
    void _sendNavControllerOutput(double bearingDeg, double distM);
    void _sendDepthMessages(double distanceM, bool healthy, uint32_t nowMs);
    void _sendTemperature(float tempC, uint32_t nowMs);
    void _setMode(uint32_t customMode);
    void _statusText(uint8_t severity, const QString &text);
    void _applyPosition();

    MockLink *_mockLink = nullptr;

    // Local frame origin (start/home position)
    double _originLat = 0;
    double _originLon = 0;

    // Boat state in local frame
    double _northM = 0;
    double _eastM = 0;
    double _headingDeg = 0;
    double _speedMS = 0;
    double _cruiseSpeedMS = 2.0;

    // Mission
    QList<NavPoint> _nav;
    int _navIndex = -1;
    uint16_t _missionCurrentSeq = 0;
    uint16_t _missionTotal = 0;
    bool _autoActive = false;
    bool _rtlActive = false;

    // Timing / sensor
    uint32_t _lastTickMs = 0;
    uint32_t _lastSensorMs = 0;
    uint32_t _last1HzMs = 0;
    uint32_t _lastDebugMs = 0;
    bool _wasArmed = false;
    bool _driverStartedSent = false;
    int _lastRaw = -1;
    float _lastTempC = 0;

    // ArduRover custom modes
    static constexpr uint32_t kModeHold   = 4;
    static constexpr uint32_t kModeAuto   = 10;
    static constexpr uint32_t kModeRtl    = 11;

    // Mirror of m36.lua settings
    static constexpr double kUnitM       = 0.001;  // raw -> metres (mm)
    static constexpr double kMinM        = 0.5;    // dead zone
    static constexpr double kMaxM        = 20.0;   // max valid depth
    static constexpr uint32_t kPeriodMs  = 350;    // sensor poll period
    static constexpr bool kDebugText     = true;   // m36.lua DEBUG = true -> "M36 raw=..." every 2 s

    static constexpr double kWaypointRadiusM = 2.0; // WP_RADIUS
    static constexpr double kTurnRateDegS    = 60.0;
};
