import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController(window: nil)

    func show() {
        if window == nil {
            let settings = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settings.title = L10n.settingsMenu
            settings.isReleasedWhenClosed = false
            settings.contentViewController = NSHostingController(rootView: SettingsView())
            settings.center()
            window = settings
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
