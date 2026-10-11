import AppKit
import SwiftUI

@MainActor
final class WindowSmokeDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = DashboardWindowController.shared
        precondition(controller.window == nil, "Dashboard must not be created at startup")
        let store = DeviceStore.preview([.previewOnline])
        controller.show(store: store)
        guard let dashboard = controller.window else {
            fatalError("Opening dashboard did not create a window")
        }
        precondition(dashboard.isVisible, "Dashboard must be visible when opened")
        precondition(dashboard.contentViewController is NSHostingController<DashboardView>)
        precondition(dashboard.contentMinSize == NSSize(width: 700, height: 500))
        dashboard.close()
        precondition(!dashboard.isVisible, "Closing dashboard must hide it")
        controller.show(store: store)
        precondition(controller.window === dashboard, "Reopening must reuse the same window")
        precondition(dashboard.isVisible, "Closed dashboard must reopen")
        dashboard.close()
        print("Dashboard runtime smoke check passed: on-demand creation, close and reopen.")
        NSApp.terminate(nil)
    }
}

@main
struct WindowSmoke {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = WindowSmokeDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
