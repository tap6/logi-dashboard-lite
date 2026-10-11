import Foundation

nonisolated enum HIDPPDecoding {
    static func unifiedBattery(parameters: [UInt8], reportsPercentage: Bool) -> BatteryReading? {
        guard parameters.count >= 3 else { return nil }
        let raw = Int(parameters[0])
        let percent = reportsPercentage && raw <= 100 ? raw : nil
        let level = batteryLevel(parameters[1])
        let charge = chargeState(parameters[2])
        if percent == nil, level == .unknown, charge == .unavailable {
            return nil
        }
        return BatteryReading(percent: percent, charge: charge, level: level)
    }

    static func legacyBattery(parameters: [UInt8]) -> BatteryReading? {
        guard parameters.count >= 3 else { return nil }
        let raw = Int(parameters[0])
        guard raw <= 100 else { return nil }
        return BatteryReading(percent: raw, charge: chargeState(parameters[2]), level: .unknown)
    }

    /// 接收器长寄存器 0xB5 里的短名称。首字节是子寄存器回显，第二字节是长度。
    static func codename(parameters: [UInt8]) -> String? {
        guard parameters.count > 2 else { return nil }
        let length = Int(parameters[1])
        let bytes: [UInt8]
        if (1...14).contains(length), parameters.count >= 2 + length {
            bytes = Array(parameters[2..<(2 + length)])
        } else {
            bytes = Array(parameters.dropFirst().prefix { $0 != 0 })
        }
        return sanitize(bytes)
    }

    static func hidpp2Kind(_ byte: UInt8) -> DeviceKind {
        switch byte {
        case 0: .keyboard
        case 3: .mouse
        case 4: .touchpad
        case 5: .trackball
        case 6: .presenter
        default: .other
        }
    }

    /// 配对信息第 8 个参数字节的低 4 位是接收器侧的设备类型。
    static func receiverKind(parameters: [UInt8]) -> DeviceKind {
        guard parameters.count > 7 else { return .other }
        let code = parameters[7] & 0x0F
        if code == 1 { return .keyboard }
        if code == 2 { return .mouse }
        if code == 4 { return .presenter }
        if code == 6 { return .trackball }
        if code == 7 { return .touchpad }
        return .other
    }

    static func chargeState(_ byte: UInt8) -> BatteryReading.ChargeState {
        switch byte {
        case 0: .discharging
        case 1: .charging
        case 2: .nearlyFull
        case 3: .full
        case 4: .slowCharging
        default: .unavailable
        }
    }

    static func batteryLevel(_ byte: UInt8) -> BatteryReading.Level {
        switch byte {
        case 1: .critical
        case 2: .low
        case 4: .good
        case 8: .full
        default: .unknown
        }
    }

    /// 配置目录每 4 字节一项：扇区号（大端）、是否启用、保留。0xFFFF 表示结束。
    static func profileDirectory(_ bytes: [UInt8]) -> [(sector: UInt16, enabled: Bool)] {
        var entries: [(sector: UInt16, enabled: Bool)] = []
        var index = 0
        while index + 3 < bytes.count {
            let sector = UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
            if sector == 0xFFFF { break }
            entries.append((sector, bytes[index + 2] != 0))
            index += 4
        }
        return entries
    }

    /// 配置扇区开头：回报间隔、默认档、切换档，然后 5 个小端 DPI。
    static func profileBody(_ bytes: [UInt8]) -> (reportIntervalMS: Int, dpiSlots: [Int]) {
        guard bytes.count >= 13 else { return (0, []) }
        var slots: [Int] = []
        for index in 0..<5 {
            let value = Int(bytes[3 + index * 2]) | (Int(bytes[4 + index * 2]) << 8)
            if value > 0 {
                slots.append(value)
            }
        }
        return (Int(bytes[0]), slots)
    }

    /// 灵敏度列表。大于 0xE000 的值是步进，其余是端点。0 表示结束。
    static func sensorDPIList(_ parameters: [UInt8]) -> (minimum: Int, maximum: Int, step: Int)? {
        var index = 1
        var values: [Int] = []
        var step = 0
        while index + 1 < parameters.count {
            let value = Int(parameters[index]) << 8 | Int(parameters[index + 1])
            if value == 0 { break }
            if value > 0xE000 {
                step = value - 0xE000
            } else {
                values.append(value)
            }
            index += 2
        }
        guard step > 0, let minimum = values.min(), let maximum = values.max(), maximum > minimum else { return nil }
        return (minimum, maximum, step)
    }

    static func sensorDPI(_ parameters: [UInt8]) -> Int? {
        guard parameters.count >= 3 else { return nil }
        let value = Int(parameters[1]) << 8 | Int(parameters[2])
        return value > 0 ? value : nil
    }

    static func profileTitle(bytes: [UInt8], index: Int) -> String {
        let fallback = L10n.profileFallback(index)
        let scalars = String(data: Data(bytes), encoding: .utf16LittleEndian)?
            .unicodeScalars
            .filter { $0.value >= 0x20 && $0.value < 0xFFFE } ?? []
        let text = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 24 else { return fallback }
        return text
    }

    private static func sanitize(_ bytes: [UInt8]) -> String? {
        let text = String(bytes: bytes.filter { $0 != 0 }, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-+_"))
        guard text.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return text
    }

    #if DEBUG
    static func validateFixtures() {
        let packet: [UInt8] = [0x11, 0x01, 0x06, 0x1A, 0x5B, 0x08, 0x00, 0x00]
        let message = HIDPPMessage.parse(reportID: 0x11, bytes: packet)
        precondition(message?.deviceIndex == 0x01)
        precondition(message?.parameters.first == 0x5B)

        let battery = unifiedBattery(parameters: message?.parameters ?? [], reportsPercentage: true)
        precondition(battery?.percent == 91)
        precondition(battery?.charge == .discharging)
        precondition(battery?.level == .full)

        let withoutPercent = unifiedBattery(parameters: [0x00, 0x01, 0x00], reportsPercentage: false)
        precondition(withoutPercent?.percent == nil)
        precondition(withoutPercent?.level == .critical)

        let legacy = legacyBattery(parameters: [0x50, 0x20, 0x00])
        precondition(legacy?.percent == 80)
        precondition(legacy?.charge == .discharging)

        precondition(codename(parameters: [0x40, 0x05, 0x50, 0x52, 0x4F, 0x20, 0x58, 0x00]) == "PRO X")
        precondition(hidpp2Kind(0x03) == .mouse)
        let pairing: [UInt8] = [0x20, 0x07, 0x08, 0x40, 0x93, 0x11, 0x00, 0x02]
        precondition(receiverKind(parameters: pairing) == .mouse)
        precondition(chargeState(1) == .charging)
        precondition(chargeState(2) == .nearlyFull)
        precondition(chargeState(4) == .slowCharging)

        let directory: [UInt8] = [
            0x00, 0x01, 0x01, 0xFF, 0x00, 0x02, 0x00, 0xFF,
            0x00, 0x03, 0x00, 0xFF, 0x00, 0x04, 0x00, 0xFF,
            0x00, 0x05, 0x00, 0xFF, 0xFF, 0xFF,
        ]
        let entries = profileDirectory(directory)
        precondition(entries.count == 5)
        precondition(entries[0].sector == 1 && entries[0].enabled)
        precondition(!entries[1].enabled)

        let header: [UInt8] = [0x01, 0x01, 0x00, 0x90, 0x01, 0x20, 0x03, 0x40, 0x06, 0x80, 0x0C, 0x00, 0x19]
        let profile = profileBody(header)
        precondition(profile.reportIntervalMS == 1)
        precondition(profile.dpiSlots == [400, 800, 1600, 3200, 6400])
        precondition(profileTitle(bytes: [UInt8](repeating: 0xFF, count: 8), index: 1).contains("1"))
        let sensorList: [UInt8] = [0x00, 0x00, 0x64, 0xE0, 0x32, 0x64, 0x00, 0x00]
        precondition(sensorDPIList(sensorList)?.minimum == 100)
        precondition(sensorDPIList(sensorList)?.maximum == 25600)
        precondition(sensorDPIList(sensorList)?.step == 50)
        precondition(sensorDPI([0x00, 0x03, 0x20, 0x03, 0x20]) == 800)
    }
    #endif
}
