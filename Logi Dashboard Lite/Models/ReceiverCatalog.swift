import Foundation

/// 已知的罗技接收器。优联、纳米、Bolt、Lightspeed 都走 HID++，只是产品号不同。
nonisolated enum ReceiverCatalog {
    /// 老款纳米接收器，配对槽更少，电量多在 HID++ 1.0 寄存器里。
    private static let nano: Set<Int> = [0xC517, 0xC52F, 0xC534]
    private static let unifying: Set<Int> = [0xC52B, 0xC532]
    private static let lightspeed: Set<Int> = [0xC537, 0xC539, 0xC53A, 0xC53F, 0xC545, 0xC547]
    private static let bolt: Set<Int> = [0xC548]

    static func isReceiver(productID: Int, productName: String) -> Bool {
        nano.contains(productID)
            || unifying.contains(productID)
            || lightspeed.contains(productID)
            || bolt.contains(productID)
            || productName.localizedCaseInsensitiveContains("Receiver")
    }

    static func connectionName(productID: Int, productName: String, transport: String, isReceiver: Bool) -> String {
        if isReceiver {
            if bolt.contains(productID) || productName.localizedCaseInsensitiveContains("Bolt") {
                return "Bolt"
            }
            if lightspeed.contains(productID) || productName.localizedCaseInsensitiveContains("Lightspeed") {
                return "Lightspeed"
            }
            if unifying.contains(productID) || productName.localizedCaseInsensitiveContains("Unifying") {
                return L10n.unifying
            }
            if nano.contains(productID) || productName.localizedCaseInsensitiveContains("Nano") {
                return L10n.nano
            }
            return L10n.wireless
        }
        if transport.localizedCaseInsensitiveContains("Bluetooth") {
            return L10n.bluetooth
        }
        return L10n.wired
    }
}
