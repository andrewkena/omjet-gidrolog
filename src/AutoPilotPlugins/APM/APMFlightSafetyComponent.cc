#include "APMFlightSafetyComponent.h"
#include "Vehicle.h"
#include "QGCMAVLink.h"

APMFlightSafetyComponent::APMFlightSafetyComponent(Vehicle *vehicle, AutoPilotPlugin *autopilot, QObject *parent)
    : VehicleComponent(vehicle, autopilot, AutoPilotPlugin::KnownSafetyVehicleComponent, parent)
{

}

QString APMFlightSafetyComponent::vehicleConfigJson() const
{
    return QStringLiteral(":/qml/QGroundControl/AutoPilotPlugins/APM/VehicleConfig/APMFlightSafety.VehicleConfig.json");
}

QString APMFlightSafetyComponent::description() const
{
    switch (_vehicle->vehicleType()) {
    case MAV_TYPE_SUBMARINE:
        return QStringLiteral("Настройка возврата, геозоны и предстартовых проверок.");
    case MAV_TYPE_GROUND_ROVER:
        return QStringLiteral("Настройка возврата, геозоны и предстартовых проверок.");
    case MAV_TYPE_FIXED_WING:
        return QStringLiteral("Настройка возврата, геозоны и предстартовых проверок.");
    default:
        return QStringLiteral("Настройка возврата, геозоны и предстартовых проверок.");
    }
}

QUrl APMFlightSafetyComponent::setupSource() const
{
    switch (_vehicle->vehicleType()) {
    case MAV_TYPE_FIXED_WING:
    case MAV_TYPE_QUADROTOR:
    case MAV_TYPE_COAXIAL:
    case MAV_TYPE_HELICOPTER:
    case MAV_TYPE_HEXAROTOR:
    case MAV_TYPE_OCTOROTOR:
    case MAV_TYPE_TRICOPTER:
    case MAV_TYPE_GROUND_ROVER:
        // Generated from APMFlightSafety.VehicleConfig.json
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMFlightSafetyComponent.qml"));
    case MAV_TYPE_SUBMARINE:
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMFlightSafetyComponentSub.qml"));
    default:
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMNotSupported.qml"));
    }
}

QUrl APMFlightSafetyComponent::summaryQmlSource() const
{
    switch (_vehicle->vehicleType()) {
    case MAV_TYPE_FIXED_WING:
    case MAV_TYPE_QUADROTOR:
    case MAV_TYPE_COAXIAL:
    case MAV_TYPE_HELICOPTER:
    case MAV_TYPE_HEXAROTOR:
    case MAV_TYPE_OCTOROTOR:
    case MAV_TYPE_TRICOPTER:
    case MAV_TYPE_GROUND_ROVER:
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMFlightSafetyComponentSummary.qml"));
    case MAV_TYPE_SUBMARINE:
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMFlightSafetyComponentSummarySub.qml"));
    default:
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMNotSupported.qml"));
    }
}
