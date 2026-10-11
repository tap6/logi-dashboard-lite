import Foundation

/// 一条 HID++ 报文。macOS 回调里的字节通常已经带上 Report ID。
nonisolated struct HIDPPMessage: Equatable, Sendable {
    var reportID: UInt8
    var deviceIndex: UInt8
    var featureOrSubID: UInt8
    var functionOrAddress: UInt8
    var parameters: [UInt8]

    var softwareID: UInt8 { functionOrAddress & 0x0F }

    static func parse(reportID: UInt32, bytes: [UInt8]) -> HIDPPMessage? {
        if let first = bytes.first, first == 0x10 || first == 0x11 || first == 0x12 {
            return decode(bytes)
        }
        guard reportID == 0x10 || reportID == 0x11 || reportID == 0x12 else { return nil }
        return decode([UInt8(reportID)] + bytes)
    }

    private static func decode(_ bytes: [UInt8]) -> HIDPPMessage? {
        guard bytes.count >= 4 else { return nil }
        let reportID = bytes[0]
        guard reportID == 0x10 || reportID == 0x11 || reportID == 0x12 else { return nil }
        return HIDPPMessage(
            reportID: reportID,
            deviceIndex: bytes[1],
            featureOrSubID: bytes[2],
            functionOrAddress: bytes[3],
            parameters: Array(bytes.dropFirst(4))
        )
    }
}
