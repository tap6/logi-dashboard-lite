import Foundation

nonisolated struct SensorRange: Equatable, Sendable {
    var minimum: Int
    var maximum: Int
    var step: Int
    var current: Int

    func snapped(_ dpi: Int) -> Int {
        guard step > 0, maximum >= minimum else { return dpi }
        let clamped = min(maximum, max(minimum, dpi))
        let steps = (clamped - minimum) / step
        return minimum + steps * step
    }
}

/// 鼠标里已经存好的配置。切换当前配置或灵敏度，不改写按键。
nonisolated struct DeviceControls: Equatable, Sendable {
    var profiles: [MouseProfile]
    var activeProfileIndex: Int
    var activeDPISlot: Int
    var disabledProfileCount: Int
    var managedByHost: Bool
    var sensor: SensorRange?

    var activeProfile: MouseProfile? {
        profiles.first { $0.index == activeProfileIndex }
    }

    var activeDPI: Int? {
        if let current = sensor?.current { return current }
        guard let slots = activeProfile?.dpiSlots, slots.indices.contains(activeDPISlot) else { return nil }
        return slots[activeDPISlot]
    }

    var canSwitchProfile: Bool {
        !managedByHost && profiles.count > 1
    }
}

extension DeviceControls {
    static let preview = DeviceControls(
        profiles: [
            MouseProfile(index: 1, title: "配置 1", reportIntervalMS: 1, dpiSlots: [400, 800, 1600, 3200, 6400]),
        ],
        activeProfileIndex: 1,
        activeDPISlot: 1,
        disabledProfileCount: 4,
        managedByHost: false,
        sensor: SensorRange(minimum: 100, maximum: 25600, step: 50, current: 800)
    )

    static let previewMultiple = DeviceControls(
        profiles: [
            MouseProfile(index: 1, title: "配置 1", reportIntervalMS: 1, dpiSlots: [400, 800, 1600, 3200, 6400]),
            MouseProfile(index: 2, title: "配置 2", reportIntervalMS: 2, dpiSlots: [800, 1600, 3200]),
            MouseProfile(index: 3, title: "办公", reportIntervalMS: 8, dpiSlots: [400, 1200]),
        ],
        activeProfileIndex: 2,
        activeDPISlot: 0,
        disabledProfileCount: 0,
        managedByHost: false,
        sensor: SensorRange(minimum: 100, maximum: 25600, step: 50, current: 800)
    )
}
