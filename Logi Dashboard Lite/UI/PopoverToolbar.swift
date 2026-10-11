import SwiftUI

struct PopoverToolbar: View {
    var store: DeviceStore
    @State private var selectedProfile = 0
    @State private var suppressProfileChange = true

    private var switchable: TrackedDevice? {
        store.devices.first { $0.controls?.canSwitchProfile == true && $0.link == .online }
    }

    var body: some View {
        if let device = switchable, let controls = device.controls {
            Picker(L10n.profile, selection: $selectedProfile) {
                ForEach(controls.profiles) { profile in
                    Text(profile.title).tag(profile.index)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .disabled(store.isApplyingControl)
            .accessibilityLabel(L10n.profile)
            .onAppear {
                selectedProfile = controls.activeProfileIndex
                suppressProfileChange = false
            }
            .onChange(of: controls.activeProfileIndex) { _, newValue in
                guard selectedProfile != newValue else { return }
                suppressProfileChange = true
                selectedProfile = newValue
                suppressProfileChange = false
            }
            .onChange(of: selectedProfile) { _, newValue in
                guard !suppressProfileChange else { return }
                guard newValue > 0, newValue != controls.activeProfileIndex else { return }
                let deviceID = device.id
                Task {
                    await store.selectProfile(deviceID, profile: newValue)
                    let current = store.devices.first { $0.id == deviceID }?.controls?.activeProfileIndex
                    guard let current, selectedProfile != current else { return }
                    suppressProfileChange = true
                    selectedProfile = current
                    suppressProfileChange = false
                }
            }
        }
    }
}
