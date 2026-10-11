import Foundation

nonisolated struct MouseProfile: Identifiable, Equatable, Sendable {
    var index: Int
    var title: String
    var reportIntervalMS: Int
    var dpiSlots: [Int]

    var id: Int { index }

    var reportRateText: String {
        switch reportIntervalMS {
        case 1: "1000 Hz"
        case 2: "500 Hz"
        case 4: "250 Hz"
        case 8: "125 Hz"
        default: reportIntervalMS > 0 ? "\(reportIntervalMS) ms" : L10n.rateUnknown
        }
    }
}
