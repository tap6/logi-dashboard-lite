import SwiftUI

struct DashboardView: View {
    var store: DeviceStore
    @State private var selectedID = ""
    @State private var page = DashboardPage.status

    private var device: TrackedDevice? {
        store.devices.first { $0.id == selectedID } ?? store.menuBarDevice ?? store.devices.first
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
        .frame(minWidth: 700, idealWidth: 740, maxWidth: .infinity, minHeight: 500, idealHeight: 540, maxHeight: .infinity)
        .onAppear {
            syncSelection()
            revealAboutIfNeeded()
        }
        .onChange(of: store.devices.map(\.id)) { _, _ in
            syncSelection()
        }
        .onChange(of: store.showsAbout) { _, _ in
            revealAboutIfNeeded()
        }
        .task {
            await store.refresh()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            deviceHeading
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 12)
            ForEach(DashboardPage.allCases) { item in
                DashboardMenuButton(page: item, isSelected: page == item) {
                    page = item
                }
            }
        }
        .padding(12)
        .frame(width: 200)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.primary.opacity(0.04))
    }

    @ViewBuilder
    private var deviceHeading: some View {
        if store.devices.count > 1 {
            Picker(L10n.devicePicker, selection: $selectedID) {
                ForEach(store.devices) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityLabel(L10n.devicePicker)
        } else if let device {
            Text(device.name)
                .font(.headline)
                .lineLimit(2)
            Text(device.link.label)
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            Text(L10n.notConnected)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var detail: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(page.title)
                .font(.title2)
            switch page {
            case .status:
                DashboardStatusPane(device: device, store: store)
            case .adjust:
                DashboardAdjustPane(device: device, store: store)
            case .menuBar:
                VStack(alignment: .leading, spacing: 16) {
                    LoginItemSettings()
                    MenuBarPercentSetting()
                }
            case .alerts:
                VStack(alignment: .leading, spacing: 16) {
                    LowBatterySettings()
                    Text(L10n.alertFooter)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .about:
                AboutPane()
            }
        }
    }

    private func syncSelection() {
        let ids = store.devices.map(\.id)
        if ids.contains(selectedID) { return }
        selectedID = store.menuBarDevice?.id ?? ids.first ?? ""
    }

    private func revealAboutIfNeeded() {
        guard store.showsAbout else { return }
        page = .about
        store.showsAbout = false
    }
}

private enum DashboardPage: String, CaseIterable, Identifiable {
    case status
    case adjust
    case menuBar
        case alerts
        case about

    var id: Self { self }

    var title: String {
        switch self {
        case .status: L10n.pageStatus
        case .adjust: L10n.pageAdjust
        case .menuBar: L10n.pageMenuBar
        case .alerts: L10n.pageAlerts
        case .about: L10n.pageAbout
        }
    }

    var symbol: String {
        switch self {
        case .status: "battery.100"
        case .adjust: "dot.scope"
        case .menuBar: "menubar.rectangle"
        case .alerts: "bell"
        case .about: "info.circle"
        }
    }
}

private struct DashboardMenuButton: View {
    var page: DashboardPage
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(page.title, systemImage: page.symbol)
                .font(isSelected ? .title3.bold() : .title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.16))
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct DashboardStatusPane: View {
    var device: TrackedDevice?
    var store: DeviceStore

    @AppStorage(AppPreference.lowBatteryThreshold) private var lowThreshold = 15.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var threshold: Int { Int(lowThreshold.rounded()) }

    var body: some View {
        if let device {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: device.kind.symbolName)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.headline)
                            Text("\(device.connectionName) · \(device.link.label)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        batteryReadout(device)
                        refreshButton
                    }

                    if let percent = device.battery?.percent, device.link == .online {
                        ProgressView(value: Double(percent), total: 100)
                            .tint(batteryTint(device))
                            .accessibilityLabel(L10n.battery)
                            .accessibilityValue(L10n.batteryPercentValue(percent))
                    }
                }

                if let message = statusMessage(device) {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent(L10n.sensitivity) {
                        Text(dpiText(device)).monospacedDigit()
                    }
                    LabeledContent(L10n.reportRate, value: device.controls?.activeProfile?.reportRateText ?? "—")
                    LabeledContent(L10n.profile, value: device.controls?.activeProfile?.title ?? "—")
                }

                Text(metricsFooter(device))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: device.battery)
        } else {
            ContentUnavailableView(
                L10n.noMouse,
                systemImage: "computermouse",
                description: Text(L10n.noMouseDetail)
            )
        }
    }

    private func batteryReadout(_ device: TrackedDevice) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let percent = device.battery?.percent, device.link == .online {
                Text("\(percent)%")
                    .font(.title2.monospacedDigit())
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .accessibilityLabel(L10n.batteryPercentLabel(percent))
            } else if let label = device.battery?.level.label, device.link == .online {
                Text(label)
                    .font(.headline)
            } else {
                Text(L10n.batteryUnknown)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                if let symbol = batterySymbol(device) {
                    Image(systemName: symbol)
                        .accessibilityHidden(true)
                }
                Text(device.link == .online ? device.statusText(lowAt: threshold) : device.link.label)
            }
            .font(.callout)
            .foregroundStyle(statusTint(device))
        }
    }

    private var refreshButton: some View {
        Group {
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(L10n.refreshing)
            } else {
                Button(L10n.refresh, systemImage: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(L10n.refresh)
            }
        }
    }

    private func batteryTint(_ device: TrackedDevice) -> Color {
        guard device.link == .online, let battery = device.battery else { return .secondary }
        if battery.charge.isPlugged { return .green }
        if let percent = battery.percent, percent <= threshold { return .orange }
        return .accentColor
    }

    private func statusTint(_ device: TrackedDevice) -> Color {
        guard device.link == .online, let battery = device.battery else { return .secondary }
        if battery.charge.isPlugged { return .green }
        if let percent = battery.percent, percent <= threshold { return .orange }
        return .secondary
    }

    private func batterySymbol(_ device: TrackedDevice) -> String? {
        guard device.link == .online, let battery = device.battery else { return nil }
        if battery.charge.isPlugged { return "bolt.fill" }
        if let percent = battery.percent, percent <= threshold { return "exclamationmark.triangle.fill" }
        return nil
    }

    private func statusMessage(_ device: TrackedDevice) -> String? {
        if device.link != .online { return device.idleMessage }
        if device.controls?.managedByHost == true {
            return L10n.hostManaged
        }
        if device.controls == nil {
            return L10n.noOnboard
        }
        return nil
    }

    private func dpiText(_ device: TrackedDevice) -> String {
        guard let dpi = device.controls?.activeDPI else { return "—" }
        return "\(dpi) DPI"
    }

    private func metricsFooter(_ device: TrackedDevice) -> String {
        var parts = [L10n.rateFooter]
        if let count = device.controls?.disabledProfileCount, count > 0 {
            parts.append(L10n.disabledProfiles(count))
        }
        return parts.joined(separator: " ")
    }
}

private struct DashboardAdjustPane: View {
    var device: TrackedDevice?
    var store: DeviceStore

    @State private var customOn = false
    @State private var suppressCustom = true
    @State private var sliderValue = 0.0
    @State private var dpiCommit: Task<Void, Never>?
    @State private var dpiGeneration = 0
    @State private var profileValue = 0
    @State private var suppressProfileChange = true

    var body: some View {
        if let device {
            controls(for: device)
                .onAppear {
                    syncProfile()
                    syncCustom(from: device.controls)
                }
                .onChange(of: device.id) { _, _ in
                    dpiCommit?.cancel()
                    dpiGeneration += 1
                    syncProfile()
                    syncCustom(from: device.controls)
                }
                .onChange(of: device.controls == nil) { _, missing in
                    guard !missing else { return }
                    syncCustom(from: device.controls)
                }
                .onChange(of: device.controls?.activeProfileIndex) { _, _ in
                    syncProfile()
                }
        } else {
            Text(L10n.adjustNeedsReceiver)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func controls(for device: TrackedDevice) -> some View {
        if device.link != .online {
            Text(device.idleMessage)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if device.controls?.managedByHost == true {
            Text(L10n.hostManaged)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if let controls = device.controls {
            VStack(alignment: .leading, spacing: 16) {
                if let note = store.controlNote {
                    Label(note, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
                if controls.canSwitchProfile {
                    Picker(L10n.profile, selection: $profileValue) {
                        ForEach(controls.profiles) { profile in
                            Text(profile.title).tag(profile.index)
                        }
                    }
                    .disabled(store.isApplyingControl)
                    .onChange(of: profileValue) { _, newValue in
                        guard !suppressProfileChange, newValue != controls.activeProfileIndex else { return }
                        Task { await store.selectProfile(device.id, profile: newValue) }
                    }
                }
                if let sensor = controls.sensor, sensor.maximum > sensor.minimum, sensor.step > 0 {
                    Toggle(L10n.customDPI, isOn: $customOn)
                        .onChange(of: customOn) { _, enabled in
                            guard !suppressCustom else { return }
                            if enabled {
                                sliderValue = Double(sensor.current)
                            } else {
                                dpiCommit?.cancel()
                                dpiGeneration += 1
                                Task { await store.selectDPISlot(device.id, slot: controls.activeDPISlot) }
                            }
                        }
                }
                if customOn, let sensor = controls.sensor, sensor.maximum > sensor.minimum {
                    customSlider(sensor, deviceID: device.id)
                } else if let slots = controls.activeProfile?.dpiSlots, slots.isEmpty == false {
                    presetButtons(slots, selected: controls.activeDPISlot, deviceID: device.id)
                }
                Text(customOn ? L10n.customSliderHelp : L10n.presetHelp)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(L10n.noOnboardShort)
                .foregroundStyle(.secondary)
        }
    }

    private func customSlider(_ sensor: SensorRange, deviceID: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(shownSlider) DPI")
                .font(.title2.monospacedDigit())
                .accessibilityLabel(L10n.currentDPI(shownSlider))
            Slider(
                value: $sliderValue,
                in: Double(sensor.minimum)...Double(sensor.maximum),
                step: Double(sensor.step)
            )
            .accessibilityLabel(L10n.customDPI)
            .onChange(of: sliderValue) { _, newValue in
                guard customOn, !suppressCustom else { return }
                scheduleSensor(Int(newValue.rounded()), deviceID: deviceID)
            }
            HStack {
                Text("\(sensor.minimum)")
                Spacer(minLength: 8)
                Text("\(sensor.maximum)")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private var shownSlider: Int {
        Int(sliderValue.rounded())
    }

    private func presetButtons(_ slots: [Int], selected: Int, deviceID: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.presets)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, dpi in
                    dpiButton(dpi: dpi, selected: index == selected) {
                        Task { await store.selectDPISlot(deviceID, slot: index) }
                    }
                }
            }
        }
    }

    private func scheduleSensor(_ value: Int, deviceID: String) {
        dpiGeneration += 1
        let generation = dpiGeneration
        dpiCommit?.cancel()
        dpiCommit = Task {
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, generation == dpiGeneration else { return }
            await store.setSensorDPI(deviceID, dpi: value)
            if generation == dpiGeneration {
                dpiCommit = nil
            }
        }
    }

    private func syncProfile() {
        suppressProfileChange = true
        profileValue = device?.controls?.activeProfileIndex ?? 0
        suppressProfileChange = false
    }

    private func syncCustom(from controls: DeviceControls?) {
        dpiCommit?.cancel()
        dpiGeneration += 1
        let current = controls?.sensor?.current ?? 0
        let slots = controls?.activeProfile?.dpiSlots ?? []
        let slot = controls?.activeDPISlot ?? -1
        let slotDPI = slots.indices.contains(slot) ? slots[slot] : nil
        suppressCustom = true
        customOn = slotDPI.map { current != $0 } ?? false
        sliderValue = Double(current)
        suppressCustom = false
    }

    @ViewBuilder
    private func dpiButton(dpi: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        if selected {
            Button(action: action) {
                Text("\(dpi)")
                    .monospacedDigit()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(store.isApplyingControl)
            .accessibilityLabel(L10n.dpiButton(dpi))
            .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: action) {
                Text("\(dpi)")
                    .monospacedDigit()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(store.isApplyingControl)
            .accessibilityLabel(L10n.dpiButton(dpi))
        }
    }
}
