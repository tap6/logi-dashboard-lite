import SwiftUI

struct BatteryHero: View {
    var device: TrackedDevice
    var lowThreshold: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let percent = device.battery?.percent {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(percent)")
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                } else if let label = device.battery?.level.label {
                    Text(label)
                        .font(.title2.weight(.semibold))
                }
                Spacer(minLength: 8)
                Text(device.statusText(lowAt: lowThreshold))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let percent = device.battery?.percent {
                ProgressView(value: Double(percent), total: 100)
                    .tint(barTint)
                    .accessibilityLabel(L10n.battery)
                    .accessibilityValue(L10n.batteryPercentValue(percent))
            }
        }
        .animation(.smooth(duration: 0.25), value: device.battery)
    }

    private var barTint: Color {
        guard let battery = device.battery else { return .accentColor }
        if battery.charge.isPlugged { return .green }
        if let percent = battery.percent, percent <= lowThreshold { return .orange }
        return .accentColor
    }
}
