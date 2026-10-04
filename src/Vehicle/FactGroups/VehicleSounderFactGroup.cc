#include "VehicleSounderFactGroup.h"

#include "MAVLinkLib.h"
#include "Vehicle.h"

#include <cstring>
#include <limits>

VehicleSounderFactGroup::VehicleSounderFactGroup(QObject *parent)
    : FactGroup(250, QStringLiteral(":/json/Vehicle/SounderFact.json"), parent)
    , _depthGrid(new DepthGrid(this))
{
    _addFact(&_depthFact);
    _addFact(&_depthHealthyFact);
    _addFact(&_waterTempFact);

    _depthFact.setRawValue(std::numeric_limits<double>::quiet_NaN());
    _depthHealthyFact.setRawValue(0);
    _waterTempFact.setRawValue(std::numeric_limits<double>::quiet_NaN());
}

void VehicleSounderFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    switch (message.msgid) {
    case MAVLINK_MSG_ID_WATER_DEPTH:
        _handleWaterDepth(message);
        break;
    case MAVLINK_MSG_ID_DISTANCE_SENSOR:
        _handleDistanceSensor(vehicle, message);
        break;
    case MAVLINK_MSG_ID_NAMED_VALUE_FLOAT:
        _handleNamedValueFloat(message);
        break;
    default:
        break;
    }
}

void VehicleSounderFactGroup::_handleWaterDepth(const mavlink_message_t &message)
{
    mavlink_water_depth_t waterDepth{};
    mavlink_msg_water_depth_decode(&message, &waterDepth);

    if (waterDepth.id != 0) {
        return; // first (downward) rangefinder only
    }

    _waterDepthSeen = true;
    _depthFact.setRawValue(static_cast<double>(waterDepth.distance));
    _depthHealthyFact.setRawValue(waterDepth.healthy ? 1 : 0);

    // Live depth map: only valid soundings, at the position the autopilot reports with the sounding
    if (waterDepth.healthy && (waterDepth.lat != 0 || waterDepth.lng != 0)) {
        _depthGrid->addSounding(waterDepth.lat / 1e7, waterDepth.lng / 1e7, static_cast<double>(waterDepth.distance));
    }

    _setTelemetryAvailable(true);
}

void VehicleSounderFactGroup::_handleDistanceSensor(Vehicle *vehicle, const mavlink_message_t &message)
{
    if (_waterDepthSeen) {
        return; // WATER_DEPTH is the primary source when the vehicle sends it (boat frame)
    }

    mavlink_distance_sensor_t distanceSensor{};
    mavlink_msg_distance_sensor_decode(&message, &distanceSensor);

    if (distanceSensor.orientation != MAV_SENSOR_ROTATION_PITCH_270) {
        return;
    }

    const bool healthy = (distanceSensor.current_distance >= distanceSensor.min_distance) &&
                         (distanceSensor.current_distance <= distanceSensor.max_distance);
    _depthFact.setRawValue(distanceSensor.current_distance / 100.0); // cm -> m
    _depthHealthyFact.setRawValue(healthy ? 1 : 0);

    // Live depth map (fallback source): current vehicle position
    if (healthy && vehicle) {
        const QGeoCoordinate coord = vehicle->coordinate();
        if (coord.isValid()) {
            _depthGrid->addSounding(coord.latitude(), coord.longitude(), distanceSensor.current_distance / 100.0);
        }
    }

    _setTelemetryAvailable(true);
}

void VehicleSounderFactGroup::_handleNamedValueFloat(const mavlink_message_t &message)
{
    mavlink_named_value_float_t namedValue{};
    mavlink_msg_named_value_float_decode(&message, &namedValue);

    // name is a fixed 10-byte field, not necessarily NUL terminated
    char name[sizeof(namedValue.name) + 1] = {};
    (void) std::memcpy(name, namedValue.name, sizeof(namedValue.name));

    if (std::strcmp(name, "M36TEMP") == 0) {
        _waterTempFact.setRawValue(static_cast<double>(namedValue.value));
        _setTelemetryAvailable(true);
    }
}
