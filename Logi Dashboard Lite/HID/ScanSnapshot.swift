import Foundation

nonisolated struct ScanSnapshot: Equatable, Sendable {
    var devices: [TrackedDevice]
    var receiverCount: Int
    var couldNotOpen: Bool

    static let empty = ScanSnapshot(devices: [], receiverCount: 0, couldNotOpen: false)
}
