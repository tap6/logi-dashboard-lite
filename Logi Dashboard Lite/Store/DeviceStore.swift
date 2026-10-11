import Foundation
import Observation
import os

@MainActor
@Observable
final class DeviceStore {
    var devices: [TrackedDevice] = []
    var phase: Phase = .loading
    var isRefreshing = false
    var isApplyingControl = false
    var controlNote: String?
    var lastUpdated: Date?
    var showsAbout = false

    @ObservationIgnored private var monitor: LogitechMonitor?
    @ObservationIgnored private let notifier = LowBatteryNotifier()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var plugObserver: NSObjectProtocol?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var lastApplied = 0
    @ObservationIgnored private var refreshCount = 0
    @ObservationIgnored private let logger = Logger(subsystem: "org.trustdev.Logi-Dashboard-Lite", category: "status")

    enum Phase: Equatable {
        case loading
        case ready
        case noHardware
        case receiverOnly
        case unavailable
    }

    init() {
        monitor = LogitechMonitor()
    }

    init(previewDevices: [TrackedDevice], phase: Phase) {
        devices = previewDevices
        self.phase = phase
        lastUpdated = Date()
    }

    var menuBarDevice: TrackedDevice? {
        let measured = devices.compactMap { device -> (TrackedDevice, Int)? in
            guard let percent = device.battery?.percent else { return nil }
            return (device, percent)
        }
        if let lowest = measured.min(by: { $0.1 < $1.1 })?.0 {
            return lowest
        }
        return devices.first { $0.kind == .mouse || $0.kind == .trackball } ?? devices.first
    }

    func start() {
        guard let monitor, loop == nil else { return }
        #if DEBUG
        HIDPPDecoding.validateFixtures()
        #endif
        monitor.start()
        plugObserver = NotificationCenter.default.addObserver(
            forName: LogitechMonitor.hardwareChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        loop = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { break }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard let monitor else { return }
        generation += 1
        let token = generation
        refreshCount += 1
        isRefreshing = true
        let snapshot = await monitor.scan()
        refreshCount -= 1
        isRefreshing = refreshCount > 0
        guard token >= lastApplied else { return }
        lastApplied = token
        apply(snapshot)
        await notifier.consider(devices)
    }

    func selectProfile(_ deviceID: String, profile: Int) async {
        guard let monitor else { return }
        guard devices.first(where: { $0.id == deviceID })?.controls?.activeProfileIndex != profile else { return }
        isApplyingControl = true
        controlNote = nil
        let ok = await monitor.setProfile(deviceID: deviceID, profile: profile)
        if ok {
            mutate(deviceID) { $0.controls?.activeProfileIndex = profile }
        } else {
            controlNote = L10n.profileFailed
        }
        await refresh()
        isApplyingControl = false
    }

    func selectDPISlot(_ deviceID: String, slot: Int) async {
        guard let monitor else { return }
        guard let controls = devices.first(where: { $0.id == deviceID })?.controls,
              let slots = controls.activeProfile?.dpiSlots,
              slots.indices.contains(slot) else { return }
        let slotDPI = slots[slot]
        let sameSlot = controls.activeDPISlot == slot
        let sensorMatches = controls.sensor?.current == nil || controls.sensor?.current == slotDPI
        guard !(sameSlot && sensorMatches) else { return }
        isApplyingControl = true
        controlNote = nil
        // 档位没变时，再发一次切档不会把传感器从自定义数值拉回来。
        let ok = sameSlot
            ? await monitor.setSensorDPI(deviceID: deviceID, dpi: slotDPI)
            : await monitor.setDPISlot(deviceID: deviceID, slot: slot)
        if ok {
            mutate(deviceID) {
                $0.controls?.activeDPISlot = slot
                $0.controls?.sensor?.current = slotDPI
            }
        } else {
            controlNote = L10n.dpiFailed
        }
        isApplyingControl = false
    }

    func setSensorDPI(_ deviceID: String, dpi: Int) async {
        guard let monitor else { return }
        guard let sensor = devices.first(where: { $0.id == deviceID })?.controls?.sensor else { return }
        let snapped = sensor.snapped(dpi)
        guard snapped != sensor.current else { return }
        controlNote = nil
        let ok = await monitor.setSensorDPI(deviceID: deviceID, dpi: snapped)
        if ok {
            mutate(deviceID) { $0.controls?.sensor?.current = snapped }
        } else {
            controlNote = L10n.dpiFailed
        }
    }

    private func mutate(_ deviceID: String, _ change: (inout TrackedDevice) -> Void) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        change(&devices[index])
    }

    /// 接收器上的短名称（例如 “PRO X”）不要覆盖已经读到的完整型号。
    private func mergingNames(_ incoming: [TrackedDevice], into existing: [TrackedDevice]) -> [TrackedDevice] {
        let previous = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        return incoming.map { device in
            guard let old = previous[device.id] else { return device }
            guard old.name.count > device.name.count, old.name.hasPrefix(device.name) else { return device }
            var kept = device
            kept.name = old.name
            return kept
        }
    }

    private func apply(_ snapshot: ScanSnapshot) {
        devices = mergingNames(snapshot.devices, into: devices)
        lastUpdated = Date()
        if snapshot.couldNotOpen, snapshot.devices.isEmpty {
            phase = .unavailable
        } else if snapshot.devices.isEmpty, snapshot.receiverCount > 0 {
            phase = .receiverOnly
        } else if snapshot.devices.isEmpty {
            phase = .noHardware
        } else {
            phase = .ready
        }
        #if DEBUG
        writeDebugStatus()
        #endif
    }

    #if DEBUG
    private func writeDebugStatus() {
        let lines = devices.map { device in
            let percent = device.battery?.percent.map(String.init) ?? "-"
            let charge = device.battery.map { String(describing: $0.charge) } ?? "-"
            let dpi = device.controls?.activeDPI.map(String.init) ?? "-"
            let profile = device.controls.map { "\($0.activeProfileIndex)" } ?? "-"
            return "\(device.name) | \(device.connectionName) | \(device.link) | \(device.kind) | \(percent) | \(charge) | dpi=\(dpi) profile=\(profile) | \(device.statusText(lowAt: AppPreference.threshold))"
        }
        let header = "phase=\(phase) count=\(devices.count)"
        let text = ([header] + lines).joined(separator: "\n")
        logger.log("\(text, privacy: .public)")
    }
    #endif

    static func preview(_ devices: [TrackedDevice], phase: Phase? = nil) -> DeviceStore {
        let resolved: Phase
        if let phase {
            resolved = phase
        } else {
            resolved = devices.isEmpty ? .noHardware : .ready
        }
        return DeviceStore(previewDevices: devices, phase: resolved)
    }
}
