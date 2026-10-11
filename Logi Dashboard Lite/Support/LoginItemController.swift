import Foundation
import ServiceManagement

enum LoginItemController {
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            true
        default:
            false
        }
    }

    static var note: String? {
        if SMAppService.mainApp.status == .requiresApproval {
            return L10n.loginApproval(L10n.appName)
        }
        return nil
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
