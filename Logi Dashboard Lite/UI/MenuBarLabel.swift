import AppKit
import SwiftUI

struct MenuBarLabel: View {
    var store: DeviceStore
    @AppStorage(AppPreference.showMenuBarPercent) private var showPercent = false
    @AppStorage(AppPreference.lowBatteryThreshold) private var lowThreshold = 15.0

    var body: some View {
        let device = store.menuBarDevice
        let threshold = Int(lowThreshold)
        let charging = device?.battery?.charge.isPlugged == true && device?.battery?.charge != .full
        HStack(alignment: .center, spacing: 2) {
            Image(systemName: device?.kind.symbolName ?? "computermouse")
                .font(.system(size: 15, weight: .regular))
            if let percent = percentText(device: device, threshold: threshold) {
                HStack(alignment: .center, spacing: 1) {
                    Text(percent)
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                    if charging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
            } else if charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(tint(device: device, threshold: threshold))
        .opacity(device?.link == .online ? 1 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(device: device, threshold: threshold))
        .fixedSize()
    }

    private func percentText(device: TrackedDevice?, threshold: Int) -> String? {
        guard let percent = device?.battery?.percent else { return nil }
        let plugged = device?.battery?.charge.isPlugged == true
        if showPercent || (percent <= threshold && !plugged) {
            return "\(percent)%"
        }
        return nil
    }

    private func tint(device: TrackedDevice?, threshold: Int) -> Color {
        guard let percent = device?.battery?.percent, device?.battery?.charge.isPlugged != true else {
            return .primary
        }
        return percent <= threshold ? .orange : .primary
    }

    private func accessibilityText(device: TrackedDevice?, threshold: Int) -> String {
        guard let device else { return L10n.noMouse }
        if let percent = device.battery?.percent {
            return L10n.menuAccessibility(name: device.name, percent: percent, status: device.statusText(lowAt: threshold))
        }
        return L10n.menuAccessibility(name: device.name, link: device.link.label)
    }

}
