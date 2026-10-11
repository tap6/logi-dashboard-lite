import Foundation

nonisolated struct TrackedDevice: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var kind: DeviceKind
    var connectionName: String
    var link: Link
    var battery: BatteryReading?
    var controls: DeviceControls? = nil

    enum Link: Equatable, Sendable {
        case online
        case asleep
        case offline

        var label: String {
            switch self {
            case .online: L10n.online
            case .asleep: L10n.asleep
            case .offline: L10n.offline
            }
        }
    }

    var showsBattery: Bool {
        link == .online && battery != nil
    }

    var detailLine: String {
        var parts = [connectionName, link.label]
        if let dpi = controls?.activeDPI {
            parts.append("\(dpi) DPI")
        }
        return parts.joined(separator: " · ")
    }

    var idleMessage: String {
        switch link {
        case .asleep:
            L10n.deviceAsleep(kind.noun)
        case .offline:
            L10n.deviceOffline(kind.noun)
        case .online:
            L10n.noBattery
        }
    }

    func statusText(lowAt threshold: Int) -> String {
        guard let battery else { return idleMessage }
        switch battery.charge {
        case .charging, .nearlyFull, .slowCharging:
            return L10n.charging
        case .full:
            return L10n.full
        case .discharging, .unavailable:
            break
        }
        if let percent = battery.percent {
            return percent <= threshold ? L10n.chargeSoon : L10n.batteryOK
        }
        switch battery.level {
        case .critical, .low:
            return L10n.chargeSoon
        case .good, .full:
            return L10n.batteryOK
        case .unknown:
            return L10n.batteryUnknown
        }
    }
}

extension TrackedDevice {
    static let previewOnline = TrackedDevice(
        id: "preview-online",
        name: "PRO X Wireless",
        kind: .mouse,
        connectionName: "Lightspeed",
        link: .online,
        battery: BatteryReading(percent: 91, charge: .discharging, level: .full)
    )

    static let previewLow = TrackedDevice(
        id: "preview-low",
        name: "PRO X Wireless",
        kind: .mouse,
        connectionName: "Lightspeed",
        link: .online,
        battery: BatteryReading(percent: 12, charge: .discharging, level: .low)
    )

    static let previewCharging = TrackedDevice(
        id: "preview-charging",
        name: "PRO X Wireless",
        kind: .mouse,
        connectionName: "Lightspeed",
        link: .online,
        battery: BatteryReading(percent: 64, charge: .charging, level: .good)
    )

    static let previewAsleep = TrackedDevice(
        id: "preview-asleep",
        name: "PRO X",
        kind: .mouse,
        connectionName: "Lightspeed",
        link: .asleep,
        battery: nil
    )
}
