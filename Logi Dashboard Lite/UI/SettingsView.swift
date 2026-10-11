import AppKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    var body: some View {
        Form {
            AppSettingsSections()
            Section {
                Text(L10n.unofficial)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(L10n.settingsAbout(AppRelease.version))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L10n.pageAbout)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 360)
    }
}

struct AppSettingsSections: View {
    var body: some View {
        Section {
            LoginItemSettings()
            MenuBarPercentSetting()
        } header: {
            Text(L10n.settingsMenuBar)
        }
        Section {
            LowBatterySettings()
        } header: {
            Text(L10n.settingsAlerts)
        } footer: {
            Text(L10n.alertFooter)
        }
    }

}

struct LoginItemSettings: View {
    @State private var launchAtLogin = false
    @State private var loginNote: String?
    @State private var suppressLoginChange = false

    var body: some View {
        Toggle(L10n.launchAtLogin, isOn: $launchAtLogin)
            .onAppear(perform: reload)
            .onChange(of: launchAtLogin) { _, enabled in
                guard !suppressLoginChange else { return }
                applyLogin(enabled)
            }
        if let loginNote {
            Text(loginNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func reload() {
        suppressLoginChange = true
        launchAtLogin = LoginItemController.isEnabled
        loginNote = LoginItemController.note
        suppressLoginChange = false
    }

    private func applyLogin(_ enabled: Bool) {
        guard enabled != LoginItemController.isEnabled else {
            loginNote = LoginItemController.note
            return
        }
        do {
            try LoginItemController.setEnabled(enabled)
            loginNote = LoginItemController.note
        } catch {
            loginNote = error.localizedDescription
            suppressLoginChange = true
            launchAtLogin = LoginItemController.isEnabled
            suppressLoginChange = false
        }
    }
}

struct MenuBarPercentSetting: View {
    @AppStorage(AppPreference.showMenuBarPercent) private var showPercent = false

    var body: some View {
        Toggle(L10n.showPercent, isOn: $showPercent)
    }
}

struct LowBatterySettings: View {
    @AppStorage(AppPreference.lowBatteryAlerts) private var alerts = true
    @AppStorage(AppPreference.lowBatteryThreshold) private var threshold = 15.0
    @State private var notificationDenied = false

    var body: some View {
        Toggle(L10n.lowBatteryNotify, isOn: $alerts)
            .onAppear {
                Task { await loadNotificationStatus() }
            }
        HStack {
            Slider(value: $threshold, in: 5...40, step: 5)
                .accessibilityLabel(L10n.threshold)
            Text("\(Int(threshold))%")
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
        .disabled(!alerts)
        if notificationDenied {
            Text(L10n.notificationsDenied)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(L10n.openNotifications, action: openNotificationSettings)
        }
    }

    private func loadNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationDenied = settings.authorizationStatus == .denied
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
