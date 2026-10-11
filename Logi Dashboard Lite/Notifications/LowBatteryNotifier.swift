import Foundation
import UserNotifications

@MainActor
final class LowBatteryNotifier {
    func consider(_ devices: [TrackedDevice]) async {
        guard AppPreference.alertsEnabled else { return }
        guard devices.contains(where: { $0.battery?.percent != nil }) else { return }

        let threshold = AppPreference.threshold
        var notified = Set(UserDefaults.standard.stringArray(forKey: AppPreference.notifiedDeviceIDs) ?? [])
        let shouldAsk = devices.contains { device in
            guard let battery = device.battery, let percent = battery.percent else { return false }
            return percent <= threshold && !battery.charge.isPlugged && !notified.contains(device.id)
        }

        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if shouldAsk, settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert])
            settings = await center.notificationSettings()
        }
        let canNotify = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional

        var changed = false

        for device in devices {
            guard let battery = device.battery, let percent = battery.percent else { continue }
            let identifier = "low-battery.\(device.id)"
            let shouldAlert = percent <= threshold && !battery.charge.isPlugged
            if shouldAlert, canNotify {
                guard !notified.contains(device.id) else { continue }
                let content = UNMutableNotificationContent()
                content.title = L10n.lowBatteryTitle(device.name)
                content.body = L10n.lowBatteryBody(percent)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
                try? await center.add(request)
                notified.insert(device.id)
                changed = true
            } else if percent > threshold || battery.charge.isPlugged {
                if notified.remove(device.id) != nil {
                    changed = true
                    center.removeDeliveredNotifications(withIdentifiers: [identifier])
                }
            }
        }

        if changed {
            UserDefaults.standard.set(Array(notified), forKey: AppPreference.notifiedDeviceIDs)
        }
    }
}
