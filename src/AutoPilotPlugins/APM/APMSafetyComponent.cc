#include "APMSafetyComponent.h"
#include "Vehicle.h"
#include "QGCMAVLink.h"

APMSafetyComponent::APMSafetyComponent(Vehicle *vehicle, AutoPilotPlugin *autopilot, QObject *parent)
    : VehicleComponent(vehicle, autopilot, AutoPilotPlugin::KnownSafetyVehicleComponent, parent)
{

}

QString APMSafetyComponent::vehicleConfigJson() const
{
    return QStringLiteral(":/qml/QGroundControl/AutoPilotPlugins/APM/VehicleConfig/APMSafety.VehicleConfig.json");
}

QString APMSafetyComponent::description() const
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

QUrl APMSafetyComponent::setupSource() const
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
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMSafetyComponent.qml"));
    case MAV_TYPE_SUBMARINE:
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMSafetyComponentSub.qml"));
    default:
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMNotSupported.qml"));
    }
}

QUrl APMSafetyComponent::summaryQmlSource() const
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
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMSafetyComponentSummary.qml"));
    case MAV_TYPE_SUBMARINE:
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMSafetyComponentSummarySub.qml"));
    default:
        return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMNotSupported.qml"));
    }
}
