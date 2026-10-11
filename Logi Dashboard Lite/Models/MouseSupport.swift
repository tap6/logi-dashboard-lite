import Foundation

/// 关于页里给用户看的常见型号。识别不靠这份名单，而靠 HID++。
nonisolated enum MouseSupport {
    static var summary: String { L10n.supportSummary }

    static var families: [Family] {
        [
            Family(id: "unifying", name: L10n.familyUnifying, models: "MX Master、MX Master 2S、MX Master 3、MX Anywhere 2S、MX Anywhere 3、MX Ergo、MX Vertical、M720、M525"),
            Family(id: "lightspeed", name: "Lightspeed", models: "PRO X、PRO X Superlight、PRO X Superlight 2、G305、G502 X Lightspeed、G603、G604、G703、G903"),
            Family(id: "bolt", name: "Bolt", models: "MX Master 3S、MX Anywhere 3S、Lift、Signature M650"),
            Family(id: "nano", name: L10n.familyNano, models: "M185、M220、M310、M330"),
        ]
    }

    struct Family: Identifiable, Sendable {
        var id: String
        var name: String
        var models: String
    }
}

enum AppRelease {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var developed: String { L10n.aboutDevelopedDate }

    static var notes: [String] {
        [L10n.aboutNote1, L10n.aboutNote2, L10n.aboutNote3]
    }
}
