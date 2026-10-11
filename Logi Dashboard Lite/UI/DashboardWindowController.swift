import AppKit
import SwiftUI

/// Create the dashboard only on demand, including on macOS 14 where SwiftUI's
/// defaultLaunchBehavior(.suppressed) is unavailable.
@MainActor
final class DashboardWindowController: NSWindowController {
    static let shared = DashboardWindowController(window: nil)

    func show(store: DeviceStore) {
        if window == nil {
            let dashboard = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 740, height: 540),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            dashboard.title = L10n.windowDashboard
            dashboard.isReleasedWhenClosed = false
            dashboard.contentViewController = NSHostingController(rootView: DashboardView(store: store))
            dashboard.contentMinSize = NSSize(width: 700, height: 500)
            dashboard.center()
            window = dashboard
        }
        if window?.isMiniaturized == true {
            window?.deminiaturize(nil)
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
