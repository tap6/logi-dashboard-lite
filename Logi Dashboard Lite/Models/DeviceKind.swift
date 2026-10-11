import Foundation

nonisolated enum DeviceKind: Equatable, Sendable {
    case mouse
    case keyboard
    case trackball
    case touchpad
    case presenter
    case other

    var symbolName: String {
        switch self {
        case .mouse, .trackball:
            "computermouse"
        case .keyboard:
            "keyboard"
        case .touchpad:
            "rectangle.and.hand.point.up.left"
        case .presenter:
            "av.remote"
        case .other:
            "wave.3.right"
        }
    }

    var noun: String {
        switch self {
        case .mouse, .trackball:
            L10n.mouse
        case .keyboard:
            L10n.keyboard
        default:
            L10n.device
        }
    }
}
