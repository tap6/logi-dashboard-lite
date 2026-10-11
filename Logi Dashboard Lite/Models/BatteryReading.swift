import Foundation

nonisolated struct BatteryReading: Equatable, Sendable {
    var percent: Int?
    var charge: ChargeState
    var level: Level

    enum ChargeState: Equatable, Sendable {
        case discharging
        case charging
        case nearlyFull
        case slowCharging
        case full
        case unavailable

        /// 插着电源，包括正在充电和已经充满。
        var isPlugged: Bool {
            switch self {
            case .charging, .nearlyFull, .slowCharging, .full:
                true
            case .discharging, .unavailable:
                false
            }
        }
    }

    enum Level: Equatable, Sendable {
        case critical
        case low
        case good
        case full
        case unknown

        var label: String? {
            switch self {
            case .critical: L10n.levelCritical
            case .low: L10n.levelLow
            case .good: L10n.levelGood
            case .full: L10n.levelFull
            case .unknown: nil
            }
        }
    }
}
