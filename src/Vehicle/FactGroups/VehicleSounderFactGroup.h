#pragma once

#include "FactGroup.h"
#include "DepthGrid.h"

/// GidroLog: echo sounder telemetry (Dayu M36 via m36.lua on ArduRover)
///   depth       - WATER_DEPTH.distance, or DISTANCE_SENSOR (orientation PITCH_270) if no WATER_DEPTH arrives
///   depthHealthy- 1 when the rangefinder reports a valid depth, 0 when out of range (e.g. shallower than the dead zone)
///   waterTemp   - NAMED_VALUE_FLOAT "M36TEMP"
/// Accessible from QML as vehicle.getFactGroup("sounder")
class VehicleSounderFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *depth        READ depth        CONSTANT)
    Q_PROPERTY(Fact *depthHealthy READ depthHealthy CONSTANT)
    Q_PROPERTY(Fact *waterTemp    READ waterTemp    CONSTANT)
    Q_PROPERTY(DepthGrid *depthGrid READ depthGrid  CONSTANT)   ///< live depth map built from the soundings

public:
    explicit VehicleSounderFactGroup(QObject *parent = nullptr);

    Fact *depth() { return &_depthFact; }
    Fact *depthHealthy() { return &_depthHealthyFact; }
    Fact *waterTemp() { return &_waterTempFact; }
    DepthGrid *depthGrid() { return _depthGrid; }

    // Overrides from FactGroup
    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) final;

private:
    void _handleWaterDepth(const mavlink_message_t &message);
    void _handleDistanceSensor(Vehicle *vehicle, const mavlink_message_t &message);
    void _handleNamedValueFloat(const mavlink_message_t &message);

    bool _waterDepthSeen = false;
    DepthGrid *_depthGrid = nullptr;

    Fact _depthFact = Fact(0, QStringLiteral("depth"), FactMetaData::valueTypeDouble);
    Fact _depthHealthyFact = Fact(0, QStringLiteral("depthHealthy"), FactMetaData::valueTypeUint8);
    Fact _waterTempFact = Fact(0, QStringLiteral("waterTemp"), FactMetaData::valueTypeDouble);
};
