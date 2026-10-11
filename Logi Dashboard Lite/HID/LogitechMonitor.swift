import Foundation
import IOKit
import IOKit.hid
import os

/// 只打开厂商自定义的 HID++ 接口（Usage Page 0xFF00 / 0xFF43）。
/// 鼠标和键盘接口留给系统，避免占用指针，也避免触发输入监控权限。
nonisolated final class LogitechMonitor: @unchecked Sendable {
    static let hardwareChanged = Notification.Name("org.trustdev.Logi-Dashboard-Lite.hardwareChanged")

    private let softwareID: UInt8 = 0x0A
    private let logger = Logger(subsystem: "org.trustdev.Logi-Dashboard-Lite", category: "HID")
    private let ready = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var manager: IOHIDManager?
    private var ports: [Int: Port] = [:]
    private var inbox: [HIDPPMessage] = []
    private var scanInProgress = false
    private var pending: [ScanWaiter] = []
    private var followUp: [() -> Void] = []
    private var vendorInterfaceCount = 0

    func start() {
        lock.lock()
        let alreadyStarted = thread != nil
        lock.unlock()
        guard !alreadyStarted else { return }

        let thread = Thread { [weak self] in
            self?.threadMain()
        }
        thread.name = "Logi HID++"
        thread.qualityOfService = .utility
        self.thread = thread
        thread.start()
        _ = ready.wait(timeout: .now() + 2)
    }

    func scan() async -> ScanSnapshot {
        await withCheckedContinuation { continuation in
            let waiter = ScanWaiter(continuation)
            lock.lock()
            if scanInProgress {
                pending.append(waiter)
                lock.unlock()
                return
            }
            scanInProgress = true
            lock.unlock()
            guard enqueue({ self.drain(first: waiter) }) else {
                lock.lock()
                scanInProgress = false
                lock.unlock()
                waiter.resume(.empty)
                return
            }
        }
    }

    func setProfile(deviceID: String, profile: Int) async -> Bool {
        guard (1...15).contains(profile) else { return false }
        return await perform {
            self.applyProfile(deviceID: deviceID, profile: profile)
        }
    }

    func setSensorDPI(deviceID: String, dpi: Int) async -> Bool {
        guard (1...50000).contains(dpi) else { return false }
        return await perform {
            self.applySensorDPI(deviceID: deviceID, dpi: dpi)
        }
    }

    func setDPISlot(deviceID: String, slot: Int) async -> Bool {
        guard (0...4).contains(slot) else { return false }
        return await perform {
            self.applyDPISlot(deviceID: deviceID, slot: slot)
        }
    }

    private func perform(_ work: @escaping () -> Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            let wrapped = {
                continuation.resume(returning: work())
            }
            lock.lock()
            if scanInProgress {
                followUp.append(wrapped)
                lock.unlock()
                return
            }
            scanInProgress = true
            lock.unlock()
            guard enqueue({
                wrapped()
                self.finishExclusive()
            }) else {
                lock.lock()
                scanInProgress = false
                lock.unlock()
                continuation.resume(returning: false)
                return
            }
        }
    }

    private func drain(first: ScanWaiter) {
        let snapshot = scanBlocking()
        first.resume(snapshot)
        finishExclusive()
    }

    private func finishExclusive() {
        while true {
            lock.lock()
            let commands = followUp
            followUp.removeAll()
            let waiting = pending
            pending.removeAll()
            if commands.isEmpty, waiting.isEmpty {
                scanInProgress = false
                lock.unlock()
                return
            }
            lock.unlock()
            for command in commands {
                command()
            }
            if !waiting.isEmpty {
                let snapshot = scanBlocking()
                for waiter in waiting {
                    waiter.resume(snapshot)
                }
            }
        }
    }

    private func threadMain() {
        guard let loop = CFRunLoopGetCurrent() else {
            ready.signal()
            return
        }
        runLoop = loop
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        // 只匹配厂商自定义通道。接收器上的键盘/鼠标接口是给系统指针用的，
        // 放进匹配列表会触发「输入监视」权限。
        let matching: [[String: Any]] = [
            [
                kIOHIDVendorIDKey as String: 0x046D,
                kIOHIDPrimaryUsagePageKey as String: 0xFF00,
            ],
            [
                kIOHIDVendorIDKey as String: 0x046D,
                kIOHIDPrimaryUsagePageKey as String: 0xFF43,
            ],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let plug: IOHIDDeviceCallback = { context, _, _, _ in
            guard let context else { return }
            Unmanaged<LogitechMonitor>.fromOpaque(context).takeUnretainedValue().postHardwareChanged()
        }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, plug, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, plug, context)
        IOHIDManagerScheduleWithRunLoop(manager, loop, CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        ready.signal()
        while true {
            CFRunLoopRunInMode(.defaultMode, 3600, false)
        }
    }

    private func postHardwareChanged() {
        NotificationCenter.default.post(name: Self.hardwareChanged, object: nil)
    }

    private func enqueue(_ work: @escaping () -> Void) -> Bool {
        guard let runLoop else { return false }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, work)
        CFRunLoopWakeUp(runLoop)
        return true
    }

    private func scanBlocking() -> ScanSnapshot {
        let opened = reconcile()
        if opened.isEmpty {
            return ScanSnapshot(devices: [], receiverCount: 0, couldNotOpen: vendorInterfaceCount > 0)
        }

        var devices: [TrackedDevice] = []
        var receivers = 0
        for port in opened {
            if port.isReceiver {
                receivers += 1
                devices.append(contentsOf: readReceiver(port))
            } else if let direct = readDirect(port) {
                devices.append(direct)
            }
        }
        devices.sort(by: prefersMouse)
        logger.log("scan devices=\(devices.count, privacy: .public) receivers=\(receivers, privacy: .public)")
        return ScanSnapshot(devices: devices, receiverCount: receivers, couldNotOpen: false)
    }

    private func prefersMouse(_ lhs: TrackedDevice, _ rhs: TrackedDevice) -> Bool {
        let leftMouse = lhs.kind == .mouse || lhs.kind == .trackball
        let rightMouse = rhs.kind == .mouse || rhs.kind == .trackball
        if leftMouse != rightMouse { return leftMouse }
        return lhs.id < rhs.id
    }

    private func reconcile() -> [Port] {
        guard let manager else {
            vendorInterfaceCount = 0
            return []
        }
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            vendorInterfaceCount = 0
            return []
        }

        var byLocation: [Int: IOHIDDevice] = [:]
        for device in set {
            let page = intProperty(device, kIOHIDPrimaryUsagePageKey as CFString) ?? 0
            guard page == 0xFF00 || page == 0xFF43 else { continue }
            let location = intProperty(device, kIOHIDLocationIDKey as CFString) ?? 0
            if byLocation[location] == nil {
                byLocation[location] = device
            }
        }
        vendorInterfaceCount = byLocation.count

        for id in ports.keys where byLocation[id] == nil {
            if let port = ports[id] {
                discard(port)
            }
            ports[id] = nil
        }
        for (location, device) in byLocation where ports[location] == nil {
            if let port = open(device, location: location) {
                ports[location] = port
            }
        }
        return ports.values.sorted { $0.locationID < $1.locationID }
    }

    private func open(_ device: IOHIDDevice, location: Int) -> Port? {
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            logger.error("open failed \(String(format: "%08X", result), privacy: .public)")
            return nil
        }
        let port = Port(device: device, locationID: location)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, port.buffer, 128, { context, _, _, _, reportID, report, length in
            guard let context, length > 0 else { return }
            let monitor = Unmanaged<LogitechMonitor>.fromOpaque(context).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: report, count: Int(length)))
            guard let message = HIDPPMessage.parse(reportID: reportID, bytes: bytes) else { return }
            monitor.inbox.append(message)
        }, context)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        return port
    }

    private func discard(_ port: Port) {
        IOHIDDeviceUnscheduleFromRunLoop(port.device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(port.device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private func readReceiver(_ port: Port) -> [TrackedDevice] {
        var devices: [TrackedDevice] = []
        var cache: [String: UInt8] = [:]
        for slot: UInt8 in 1...6 {
            guard let codename = readCodename(port, slot: slot) else { continue }
            let id = "\(port.locationID)-\(slot)"
            switch ping(port, device: slot) {
            case let .online(major):
                let name = (major >= 2 ? readMarketingName(port, device: slot, cache: &cache) : nil) ?? codename
                let kind = (major >= 2 ? readHIDPP2Kind(port, device: slot, cache: &cache) : nil)
                    ?? receiverKind(port, slot: slot)
                let battery = readBattery(port, device: slot, major: major, cache: &cache)
                let controls = major >= 2 ? readControls(port, device: slot, cache: &cache) : nil
                devices.append(TrackedDevice(
                    id: id,
                    name: name,
                    kind: kind,
                    connectionName: port.connectionName,
                    link: .online,
                    battery: battery,
                    controls: controls
                ))
            case .rejected:
                devices.append(TrackedDevice(
                    id: id,
                    name: codename,
                    kind: receiverKind(port, slot: slot),
                    connectionName: port.connectionName,
                    link: .offline,
                    battery: nil
                ))
            case .timedOut:
                devices.append(TrackedDevice(
                    id: id,
                    name: codename,
                    kind: receiverKind(port, slot: slot),
                    connectionName: port.connectionName,
                    link: .asleep,
                    battery: nil
                ))
            }
        }
        return devices
    }

    private func readDirect(_ port: Port) -> TrackedDevice? {
        guard case let .online(major) = ping(port, device: 0xFF) else { return nil }
        var cache: [String: UInt8] = [:]
        let fallback = port.productName.isEmpty ? L10n.fallbackDeviceName : port.productName
        if major >= 2 {
            let name = readMarketingName(port, device: 0xFF, cache: &cache) ?? fallback
            let kind = readHIDPP2Kind(port, device: 0xFF, cache: &cache) ?? .mouse
            let battery = readBattery(port, device: 0xFF, major: major, cache: &cache)
            let controls = readControls(port, device: 0xFF, cache: &cache)
            return TrackedDevice(
                id: "\(port.locationID)-direct",
                name: name,
                kind: kind,
                connectionName: port.connectionName,
                link: .online,
                battery: battery,
                controls: controls
            )
        }
        guard let battery = readBattery(port, device: 0xFF, major: major, cache: &cache) else { return nil }
        return TrackedDevice(
            id: "\(port.locationID)-direct",
            name: fallback,
            kind: .mouse,
            connectionName: port.connectionName,
            link: .online,
            battery: battery
        )
    }

    private func applyProfile(deviceID: String, profile: Int) -> Bool {
        guard let target = openTarget(deviceID) else { return false }
        guard case .online = ping(target.port, device: target.device) else { return false }
        var cache: [String: UInt8] = [:]
        guard let feature = featureIndex(target.port, device: target.device, feature: 0x8100, cache: &cache), feature != 0 else {
            return false
        }
        guard case .value = request(
            target.port,
            device: target.device,
            featureIndex: feature,
            function: 3,
            params: [0x00, UInt8(profile)],
            timeout: 0.8
        ) else { return false }
        return true
    }

    private func applyDPISlot(deviceID: String, slot: Int) -> Bool {
        guard let target = openTarget(deviceID) else { return false }
        guard case .online = ping(target.port, device: target.device) else { return false }
        var cache: [String: UInt8] = [:]
        guard let feature = featureIndex(target.port, device: target.device, feature: 0x8100, cache: &cache), feature != 0 else {
            return false
        }
        guard case .value = request(
            target.port,
            device: target.device,
            featureIndex: feature,
            function: 0x0C,
            params: [UInt8(slot)],
            timeout: 0.8
        ) else { return false }
        return true
    }

    private func applySensorDPI(deviceID: String, dpi: Int) -> Bool {
        guard let target = openTarget(deviceID) else { return false }
        guard case .online = ping(target.port, device: target.device) else { return false }
        var cache: [String: UInt8] = [:]
        guard let feature = featureIndex(target.port, device: target.device, feature: 0x2201, cache: &cache), feature != 0 else {
            return false
        }
        let value = UInt16(dpi)
        guard case let .value(message) = request(
            target.port,
            device: target.device,
            featureIndex: feature,
            function: 3,
            params: [0x00, UInt8(value >> 8), UInt8(value & 0xFF)],
            timeout: 0.8
        ) else { return false }
        guard let echoed = HIDPPDecoding.sensorDPI(message.parameters) else { return true }
        return echoed == dpi
    }

    private func openTarget(_ deviceID: String) -> (port: Port, device: UInt8)? {
        guard let address = address(for: deviceID) else { return nil }
        guard let port = reconcile().first(where: { $0.locationID == address.location }) else { return nil }
        return (port, address.device)
    }

    private func address(for deviceID: String) -> (location: Int, device: UInt8)? {
        let parts = deviceID.split(separator: "-", maxSplits: 1).map(String.init)
        guard parts.count == 2, let location = Int(parts[0]) else { return nil }
        if parts[1] == "direct" { return (location, 0xFF) }
        guard let slot = UInt8(parts[1]) else { return nil }
        return (location, slot)
    }

    private func readControls(_ port: Port, device: UInt8, cache: inout [String: UInt8]) -> DeviceControls? {
        guard let feature = featureIndex(port, device: device, feature: 0x8100, cache: &cache), feature != 0 else {
            return nil
        }
        guard case let .value(profileMessage) = request(
            port,
            device: device,
            featureIndex: feature,
            function: 4,
            params: [],
            timeout: 0.8
        ), profileMessage.parameters.count > 1 else { return nil }

        let active = Int(profileMessage.parameters[1])
        let managedByHost = active == 0
        let dpiSlot: Int
        if case let .value(dpiMessage) = request(
            port,
            device: device,
            featureIndex: feature,
            function: 0x0B,
            params: [],
            timeout: 0.8
        ), let raw = dpiMessage.parameters.first {
            dpiSlot = Int(raw)
        } else {
            dpiSlot = 0
        }

        let directory = readProfileDirectory(port, device: device, feature: feature)
        var profiles: [MouseProfile] = []
        var disabled = 0
        for (offset, entry) in directory.enumerated() {
            let index = offset + 1
            guard entry.enabled else {
                disabled += 1
                continue
            }
            guard let header = readMemory(port, device: device, feature: feature, sector: entry.sector, offset: 0) else {
                continue
            }
            let body = HIDPPDecoding.profileBody(header)
            let nameBytes = (readMemory(port, device: device, feature: feature, sector: entry.sector, offset: 160) ?? [])
                + (readMemory(port, device: device, feature: feature, sector: entry.sector, offset: 176) ?? [])
            profiles.append(MouseProfile(
                index: index,
                title: HIDPPDecoding.profileTitle(bytes: nameBytes, index: index),
                reportIntervalMS: body.reportIntervalMS,
                dpiSlots: body.dpiSlots
            ))
        }
        guard managedByHost || !profiles.isEmpty else { return nil }
        let sensor = readSensorRange(port, device: device, cache: &cache)
        logger.log("controls profiles=\(profiles.count, privacy: .public) active=\(active, privacy: .public) dpiSlot=\(dpiSlot, privacy: .public) dpi=\(sensor?.current ?? -1, privacy: .public)")
        return DeviceControls(
            profiles: profiles,
            activeProfileIndex: active,
            activeDPISlot: dpiSlot,
            disabledProfileCount: disabled,
            managedByHost: managedByHost,
            sensor: sensor
        )
    }

    private func readSensorRange(_ port: Port, device: UInt8, cache: inout [String: UInt8]) -> SensorRange? {
        guard let feature = featureIndex(port, device: device, feature: 0x2201, cache: &cache), feature != 0 else {
            return nil
        }
        guard case let .value(list) = request(port, device: device, featureIndex: feature, function: 1, params: [0], timeout: 0.8),
              let parsed = HIDPPDecoding.sensorDPIList(list.parameters) else { return nil }
        guard case let .value(current) = request(port, device: device, featureIndex: feature, function: 2, params: [0], timeout: 0.8),
              let dpi = HIDPPDecoding.sensorDPI(current.parameters) else { return nil }
        return SensorRange(minimum: parsed.minimum, maximum: parsed.maximum, step: parsed.step, current: dpi)
    }

    private func readProfileDirectory(_ port: Port, device: UInt8, feature: UInt8) -> [(sector: UInt16, enabled: Bool)] {
        var bytes: [UInt8] = []
        var offset: UInt16 = 0
        while offset < 64 {
            guard let chunk = readMemory(port, device: device, feature: feature, sector: 0, offset: offset) else { break }
            bytes.append(contentsOf: chunk)
            offset += 16
            if stride(from: 0, to: bytes.count, by: 4).contains(where: { index in
                index + 1 < bytes.count && (UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])) == 0xFFFF
            }) {
                break
            }
        }
        return HIDPPDecoding.profileDirectory(bytes)
    }

    private func readMemory(_ port: Port, device: UInt8, feature: UInt8, sector: UInt16, offset: UInt16) -> [UInt8]? {
        guard case let .value(message) = request(
            port,
            device: device,
            featureIndex: feature,
            function: 5,
            params: [UInt8(sector >> 8), UInt8(sector & 0xFF), UInt8(offset >> 8), UInt8(offset & 0xFF)],
            timeout: 0.45
        ), message.parameters.count >= 16 else { return nil }
        return Array(message.parameters.prefix(16))
    }

    private func readCodename(_ port: Port, slot: UInt8) -> String? {
        let subs = [UInt8(0x40 + slot - 1), slot | 0x60]
        for sub in subs {
            if case let .value(message) = readLong(port, address: 0xB5, sub: sub),
               let name = HIDPPDecoding.codename(parameters: message.parameters) {
                return name
            }
        }
        return nil
    }

    private func receiverKind(_ port: Port, slot: UInt8) -> DeviceKind {
        let subs = [UInt8(0x20 + slot - 1), slot | 0x50]
        for sub in subs {
            if case let .value(message) = readLong(port, address: 0xB5, sub: sub) {
                let kind = HIDPPDecoding.receiverKind(parameters: message.parameters)
                if kind != .other { return kind }
            }
        }
        return .other
    }

    private func ping(_ port: Port, device: UInt8) -> Ping {
        let first = pingOnce(port, device: device)
        if case .timedOut = first {
            // 第一包常常只负责把休眠中的鼠标唤醒，第二包才能拿到协议版本。
            return pingOnce(port, device: device)
        }
        return first
    }

    private func pingOnce(_ port: Port, device: UInt8) -> Ping {
        switch request(port, device: device, featureIndex: 0, function: 1, params: [0x00, 0x00, 0x5A], timeout: 0.9) {
        case let .value(message):
            guard message.parameters.count >= 3, message.parameters[2] == 0x5A else { return .timedOut }
            return .online(major: message.parameters[0])
        case .rejected:
            return .rejected
        case .timedOut, .transportFailure:
            return .timedOut
        }
    }

    private func readMarketingName(_ port: Port, device: UInt8, cache: inout [String: UInt8]) -> String? {
        guard let index = featureIndex(port, device: device, feature: 0x0005, cache: &cache), index != 0 else {
            return nil
        }
        guard case let .value(countMessage) = requestRetrying(port, device: device, featureIndex: index, function: 0) else {
            return nil
        }
        let length = Int(countMessage.parameters.first ?? 0)
        guard length > 0 else { return nil }

        var bytes: [UInt8] = []
        var offset = 0
        while offset < length, offset < 64 {
            let take = min(16, length - offset)
            guard case let .value(chunk) = requestRetrying(
                port,
                device: device,
                featureIndex: index,
                function: 1,
                params: [UInt8(offset)]
            ), chunk.parameters.count >= take else { break }
            bytes.append(contentsOf: chunk.parameters.prefix(take))
            offset += take
        }
        let text = String(bytes: bytes.filter { $0 != 0 }, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    private func readHIDPP2Kind(_ port: Port, device: UInt8, cache: inout [String: UInt8]) -> DeviceKind? {
        guard let index = featureIndex(port, device: device, feature: 0x0005, cache: &cache), index != 0 else {
            return nil
        }
        guard case let .value(message) = request(port, device: device, featureIndex: index, function: 2, params: [], timeout: 0.8),
              let byte = message.parameters.first else { return nil }
        let kind = HIDPPDecoding.hidpp2Kind(byte)
        return kind == .other ? nil : kind
    }

    private func readBattery(_ port: Port, device: UInt8, major: UInt8, cache: inout [String: UInt8]) -> BatteryReading? {
        if major >= 2 {
            if let index = featureIndex(port, device: device, feature: 0x1004, cache: &cache), index != 0 {
                let reportsPercentage = percentageSupported(port, device: device, featureIndex: index)
                if case let .value(message) = requestRetrying(port, device: device, featureIndex: index, function: 1),
                   let reading = HIDPPDecoding.unifiedBattery(parameters: message.parameters, reportsPercentage: reportsPercentage) {
                    return reading
                }
            }
            if let index = featureIndex(port, device: device, feature: 0x1000, cache: &cache), index != 0 {
                if case let .value(message) = requestRetrying(port, device: device, featureIndex: index, function: 0),
                   let reading = HIDPPDecoding.legacyBattery(parameters: message.parameters) {
                    return reading
                }
            }
        }
        if case let .value(message) = readShort(port, device: device, address: 0x07) {
            return HIDPPDecoding.legacyBattery(parameters: message.parameters)
        }
        return nil
    }

    private func percentageSupported(_ port: Port, device: UInt8, featureIndex: UInt8) -> Bool {
        guard case let .value(message) = request(port, device: device, featureIndex: featureIndex, function: 0, params: [], timeout: 0.8),
              message.parameters.count > 1 else { return true }
        return message.parameters[1] & 0x02 != 0
    }

    private func featureIndex(_ port: Port, device: UInt8, feature: UInt16, cache: inout [String: UInt8]) -> UInt8? {
        let key = "\(device)-\(String(format: "%04X", feature))"
        if let cached = cache[key] { return cached }
        let reply = requestRetrying(
            port,
            device: device,
            featureIndex: 0,
            function: 0,
            params: [UInt8(feature >> 8), UInt8(feature & 0xFF)]
        )
        guard case let .value(message) = reply, let index = message.parameters.first else { return nil }
        cache[key] = index
        return index
    }

    private func requestRetrying(
        _ port: Port,
        device: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8] = []
    ) -> Reply {
        let first = request(port, device: device, featureIndex: featureIndex, function: function, params: params, timeout: 0.8)
        if case .timedOut = first {
            return request(port, device: device, featureIndex: featureIndex, function: function, params: params, timeout: 0.8)
        }
        return first
    }

    private func request(
        _ port: Port,
        device: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        params: [UInt8],
        timeout: TimeInterval
    ) -> Reply {
        var packet = [UInt8](repeating: 0, count: 20)
        packet[0] = 0x11
        packet[1] = device
        packet[2] = featureIndex
        packet[3] = (function << 4) | softwareID
        for (offset, byte) in params.prefix(16).enumerated() {
            packet[4 + offset] = byte
        }
        return transact(port, packet: packet, timeout: timeout) { message in
            guard message.deviceIndex == device else { return false }
            if message.featureOrSubID == 0xFF {
                return message.softwareID == self.softwareID
            }
            if message.featureOrSubID == 0x8F {
                let echoed = message.parameters.first ?? 0
                return echoed & 0x0F == self.softwareID
            }
            return message.featureOrSubID == featureIndex && message.softwareID == self.softwareID
        }
    }

    private func readShort(_ port: Port, device: UInt8, address: UInt8) -> Reply {
        var packet = [UInt8](repeating: 0, count: 7)
        packet[0] = 0x10
        packet[1] = device
        packet[2] = 0x81
        packet[3] = address
        return transact(port, packet: packet, timeout: 0.45) { message in
            guard message.deviceIndex == device else { return false }
            if message.featureOrSubID == 0x8F { return true }
            return message.featureOrSubID == 0x81 && message.functionOrAddress == address
        }
    }

    private func readLong(_ port: Port, address: UInt8, sub: UInt8) -> Reply {
        var packet = [UInt8](repeating: 0, count: 7)
        packet[0] = 0x10
        packet[1] = 0xFF
        packet[2] = 0x83
        packet[3] = address
        packet[4] = sub
        return transact(port, packet: packet, timeout: 0.45) { message in
            guard message.deviceIndex == 0xFF else { return false }
            if message.featureOrSubID == 0x8F { return true }
            return message.featureOrSubID == 0x83 && message.functionOrAddress == address
        }
    }

    private func transact(_ port: Port, packet: [UInt8], timeout: TimeInterval, accepts: (HIDPPMessage) -> Bool) -> Reply {
        inbox.removeAll()
        var data = packet
        let reportID = CFIndex(data[0])
        let result = data.withUnsafeMutableBufferPointer { raw in
            IOHIDDeviceSetReport(port.device, kIOHIDReportTypeOutput, reportID, raw.baseAddress!, raw.count)
        }
        guard result == kIOReturnSuccess else { return .transportFailure }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let index = inbox.firstIndex(where: accepts) {
                return classify(inbox.remove(at: index))
            }
            let slice = min(0.05, max(0.01, deadline.timeIntervalSinceNow))
            CFRunLoopRunInMode(.defaultMode, slice, false)
        }
        return .timedOut
    }

    private func classify(_ message: HIDPPMessage) -> Reply {
        if message.featureOrSubID == 0x8F {
            let code = message.parameters.count > 1 ? message.parameters[1] : 0xFF
            return .rejected(code)
        }
        if message.featureOrSubID == 0xFF {
            return .rejected(message.parameters.first ?? 0xFF)
        }
        return .value(message)
    }

    private func intProperty(_ device: IOHIDDevice, _ key: CFString) -> Int? {
        let value = IOHIDDeviceGetProperty(device, key)
        if let number = value as? NSNumber { return number.intValue }
        if let number = value as? Int { return number }
        return nil
    }

    private enum Reply {
        case value(HIDPPMessage)
        case rejected(UInt8)
        case timedOut
        case transportFailure
    }

    private enum Ping {
        case online(major: UInt8)
        case rejected
        case timedOut
    }

    private final class Port {
        let device: IOHIDDevice
        let buffer: UnsafeMutablePointer<UInt8>
        let locationID: Int
        let productID: Int
        let productName: String
        let connectionName: String
        let isReceiver: Bool

        init(device: IOHIDDevice, locationID: Int) {
            self.device = device
            self.locationID = locationID
            buffer = .allocate(capacity: 128)
            buffer.initialize(repeating: 0, count: 128)
            productID = (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber)?.intValue ?? 0
            productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
            let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""
            isReceiver = ReceiverCatalog.isReceiver(productID: productID, productName: productName)
            connectionName = ReceiverCatalog.connectionName(
                productID: productID,
                productName: productName,
                transport: transport,
                isReceiver: isReceiver
            )
        }

        deinit {
            buffer.deinitialize(count: 128)
            buffer.deallocate()
        }
    }

    private final class ScanWaiter: @unchecked Sendable {
        private var continuation: CheckedContinuation<ScanSnapshot, Never>?

        init(_ continuation: CheckedContinuation<ScanSnapshot, Never>) {
            self.continuation = continuation
        }

        func resume(_ snapshot: ScanSnapshot) {
            continuation?.resume(returning: snapshot)
            continuation = nil
        }
    }
}
