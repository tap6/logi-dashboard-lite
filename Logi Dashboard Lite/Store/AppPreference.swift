import Foundation

enum AppPreference {
    static let showMenuBarPercent = "showMenuBarPercent"
    static let lowBatteryAlerts = "lowBatteryAlerts"
    static let lowBatteryThreshold = "lowBatteryThreshold"
    static let notifiedDeviceIDs = "lowBatteryNotifiedDeviceIDs"

    static var alertsEnabled: Bool {
        if UserDefaults.standard.object(forKey: lowBatteryAlerts) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: lowBatteryAlerts)
    }

    static var threshold: Int {
        if UserDefaults.standard.object(forKey: lowBatteryThreshold) == nil {
            return 15
        }
        return Int(UserDefaults.standard.double(forKey: lowBatteryThreshold).rounded())
    }
}
