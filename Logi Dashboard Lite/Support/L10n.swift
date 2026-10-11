import Foundation

nonisolated enum L10n {
    static var appName: String { text("app.name", "Logi Lite") }
    static var unofficial: String { text("app.unofficial", "Unofficial software. Not affiliated with Logitech.") }

    static var online: String { text("link.online", "Online") }
    static var asleep: String { text("link.asleep", "Asleep") }
    static var offline: String { text("link.offline", "Offline") }

    static var mouse: String { text("kind.mouse", "mouse") }
    static var keyboard: String { text("kind.keyboard", "keyboard") }
    static var device: String { text("kind.device", "device") }

    static var charging: String { text("status.charging", "Charging") }
    static var full: String { text("status.full", "Fully charged") }
    static var chargeSoon: String { text("status.low", "Charge soon") }
    static var batteryOK: String { text("status.ok", "Battery is fine") }
    static var batteryUnknown: String { text("status.unknown", "Battery unknown") }
    static var levelCritical: String { text("level.critical", "Critically low") }
    static var levelLow: String { text("level.low", "Low") }
    static var levelGood: String { text("level.good", "Good") }
    static var levelFull: String { text("level.full", "Full") }

    static var unifying: String { text("connection.unifying", "Unifying") }
    static var nano: String { text("connection.nano", "Nano") }
    static var wireless: String { text("connection.wireless", "Wireless") }
    static var bluetooth: String { text("connection.bluetooth", "Bluetooth") }
    static var wired: String { text("connection.wired", "Wired") }

    static var rateUnknown: String { text("profile.unknown", "Unknown") }
    static var pageStatus: String { text("page.status", "Status") }
    static var pageAdjust: String { text("page.adjust", "Adjust") }
    static var pageMenuBar: String { text("page.menuBar", "Menu Bar") }
    static var pageAlerts: String { text("page.alerts", "Alerts") }
    static var pageAbout: String { text("page.about", "About") }
    static var windowDashboard: String { text("window.dashboard", "Dashboard") }

    static var refresh: String { text("action.refresh", "Refresh") }
    static var dashboard: String { text("action.dashboard", "Dashboard") }
    static var openNotifications: String { text("action.openNotifications", "Open Notification Settings") }
    static var refreshing: String { text("state.refreshing", "Refreshing") }

    static var devicePicker: String { text("label.device", "Device") }
    static var notConnected: String { text("label.disconnected", "Not connected") }
    static var sensitivity: String { text("label.dpi", "Sensitivity") }
    static var reportRate: String { text("label.reportRate", "Report rate") }
    static var profile: String { text("label.profile", "Profile") }
    static var presets: String { text("label.preset", "Presets") }
    static var customDPI: String { text("label.customDPI", "Custom sensitivity") }
    static var threshold: String { text("label.threshold", "Alert threshold") }
    static var battery: String { text("label.battery", "Battery") }

    static var noMouse: String { text("empty.noMouse", "No Logitech mouse found") }
    static var noMouseDetail: String { text("empty.noMouseDetail", "Plug in a receiver and the battery and connection will show up here.") }
    static var adjustNeedsReceiver: String { text("empty.adjustNeedsReceiver", "Plug in a receiver before adjusting sensitivity.") }
    static var hostManaged: String { text("device.hostManaged", "Another app is controlling this mouse. Quit that app before adjusting it here.") }
    static var noOnboard: String { text("device.noOnboard", "This device has no onboard profile. Battery and connection still show above.") }
    static var noOnboardShort: String { text("device.noOnboardShort", "This device has no onboard profile.") }
    static var rateFooter: String { text("metrics.rateFooter", "Report rate comes from the onboard profile and is shown here only.") }
    static var customSliderHelp: String { text("custom.sliderHelp", "The slider changes the current sensitivity and leaves the presets alone. Turn it off to return to the selected preset.") }
    static var presetHelp: String { text("custom.presetHelp", "Presets match the DPI button on the mouse. Turn on the switch above for a custom value.") }
    static var alertFooter: String { text("alert.footer", "You’ll be notified once when it drops to the threshold. It can alert again after charging starts, or after the battery rises above the threshold.") }

    static var settingsMenuBar: String { text("settings.menuBar", "Menu Bar") }
    static var settingsAlerts: String { text("settings.alerts", "Alerts") }
    static var launchAtLogin: String { text("settings.launchAtLogin", "Launch at login") }
    static var showPercent: String { text("settings.showPercent", "Show battery percentage in the menu bar") }
    static var lowBatteryNotify: String { text("settings.lowBattery", "Notify when the battery is low") }
    static var notificationsDenied: String { text("settings.notificationsDenied", "Notifications are turned off. Allow Logi Lite in System Settings → Notifications.") }

    static var profileFailed: String { text("control.profileFailed", "Couldn’t switch profiles. Move the mouse and try again.") }
    static var dpiFailed: String { text("control.dpiFailed", "Couldn’t change sensitivity. Move the mouse and try again.") }

    static var popoverLoadingTitle: String { text("popover.loading.title", "Reading the mouse…") }
    static var popoverLoadingMessage: String { text("popover.loading.message", "This usually takes a second or two.") }
    static var popoverNoHardwareMessage: String { text("popover.noHardware.message", "Plug in a receiver, or connect over Bluetooth, and the battery will show up here.") }
    static var popoverReceiverTitle: String { text("popover.receiver.title", "Receiver connected") }
    static var popoverReceiverMessage: String { text("popover.receiver.message", "No mouse is paired. If it is asleep, move it and refresh.") }
    static var popoverUnavailableTitle: String { text("popover.unavailable.title", "Can’t read the receiver") }
    static var popoverUnavailableMessage: String { text("popover.unavailable.message", "If Logitech’s own app is using it, quit that app and refresh.") }
    static var popoverFooterControls: String { text("popover.footer.controls", "The dashboard switches profiles and sensitivity already saved on the mouse.") }
    static var popoverFooterReadOnly: String { text("popover.footer.readOnly", "Status is read-only. Mouse settings are not changed.") }

    static var aboutProduct: String { text("about.product", "Logi Lite") }
    static var aboutWhatsNew: String { text("about.whatsNew", "What’s new") }
    static var aboutSupported: String { text("about.supported", "Common mouse models") }
    static var aboutNote1: String { text("about.note1", "See battery, charging, and connection in the menu bar.") }
    static var aboutNote2: String { text("about.note2", "See status in the dashboard, and change sensitivity with presets or a custom slider.") }
    static var aboutNote3: String { text("about.note3", "Get a low-battery notification, and optionally launch at login.") }
    static var aboutDevelopedDate: String { text("about.developedDate", "October 2026") }
    static var supportSummary: String { text("support.summary", "Hardware reads are verified on PRO X Wireless over Lightspeed. Other models below are references, not a fully tested list. Battery reads require an accessible HID++ interface and battery feature. DPI and profiles require the corresponding device features.") }
    static var familyUnifying: String { text("support.family.unifying", "Unifying") }
    static var familyNano: String { text("support.family.nano", "Nano receiver") }
    static var fallbackDeviceName: String { text("device.fallbackName", "Logitech device") }
    static var aboutMenu: String { text("menu.about", "About Logi Lite") }
    static var settingsMenu: String { text("menu.settings", "Settings…") }
    static var checkForUpdates: String { text("menu.checkUpdates", "Check for Updates…") }
    static var quit: String { text("menu.quit", "Quit") }
    static var updateTitle: String { text("update.title", "You’re Up to Date") }
    static var ok: String { text("action.ok", "OK") }

    static func updateUpToDate(_ name: String, _ version: String) -> String {
        format("update.body", "%1$@ %2$@ is the latest version.", name, version)
    }

    static func deviceAsleep(_ noun: String) -> String {
        format("device.asleep", "%@ is asleep. Move it, then refresh to read the battery.", noun)
    }

    static func deviceOffline(_ noun: String) -> String {
        format("device.offline", "The receiver is still connected, but this %@ is not.", noun)
    }

    static var noBattery: String { text("device.noBattery", "Battery reading isn’t available yet.") }

    static func profileFallback(_ index: Int) -> String {
        format("profile.fallback", "Profile %lld", index)
    }

    static func menuAccessibility(name: String, percent: Int, status: String) -> String {
        format("menu.axDevice", "%1$@, battery %2$lld percent, %3$@", name, percent, status)
    }

    static func menuAccessibility(name: String, link: String) -> String {
        format("menu.axLink", "%1$@, %2$@", name, link)
    }

    static func batteryPercentValue(_ percent: Int) -> String {
        format("battery.percentValue", "%lld percent", percent)
    }

    static func batteryPercentLabel(_ percent: Int) -> String {
        format("battery.percentLabel", "Battery %lld percent", percent)
    }

    static func currentDPI(_ dpi: Int) -> String {
        format("battery.currentDPI", "Current %lld DPI", dpi)
    }

    static func disabledProfiles(_ count: Int) -> String {
        format("metrics.disabledFooter", "%lld more profiles are not enabled.", count)
    }

    static func dpiButton(_ dpi: Int) -> String {
        format("a11y.dpi", "%lld DPI", dpi)
    }

    static func loginApproval(_ appName: String) -> String {
        format("login.needsApproval", "macOS still needs you to allow %@ in System Settings → General → Login Items & Extensions.", appName)
    }

    static func lowBatteryTitle(_ name: String) -> String {
        format("notify.title", "%@ battery is low", name)
    }

    static func lowBatteryBody(_ percent: Int) -> String {
        format("notify.body", "%lld%% remaining. Charge it soon.", percent)
    }

    static func aboutVersion(_ version: String, _ build: String) -> String {
        format("about.version", "Version %1$@ (%2$@)", version, build)
    }

    static func aboutDeveloped(_ date: String) -> String {
        format("about.developed", "Developed %@", date)
    }

    static func settingsAbout(_ version: String) -> String {
        format("about.settingsHint", "Version %@. Supported mice are listed in the dashboard’s About page.", version)
    }

    private static func text(_ key: StaticString, _ fallback: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: fallback)
    }

    private static func format(_ key: StaticString, _ fallback: String.LocalizationValue, _ args: CVarArg...) -> String {
        String(format: text(key, fallback), locale: .current, arguments: args)
    }
}
