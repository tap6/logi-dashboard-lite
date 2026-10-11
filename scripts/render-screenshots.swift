import AppKit
import SwiftUI

/// Export real app views using a read-only snapshot from the connected hardware.
/// No serial numbers, location IDs, or user preferences are written to images.
@main
struct ScreenshotExporter {
    @MainActor
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count > 1 else { fatalError("Usage: ScreenshotExporter <output-directory>") }
        let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .aqua)

        let monitor = LogitechMonitor()
        monitor.start()
        Task { @MainActor in
            let snapshot = await monitor.scan()
            guard !snapshot.devices.isEmpty else { fatalError("No connected HID++ device. No fabricated screenshot will be exported.") }
            var devices = snapshot.devices
            for index in devices.indices { devices[index].id = "documentation-device-\(index)" }
            let store = DeviceStore.preview(devices)
            for device in devices {
                print("Captured: \(device.name), \(device.connectionName), battery=\(device.battery?.percent ?? -1), DPI=\(device.controls?.activeDPI ?? -1)")
            }

            let popover = arguments.contains("--popover")
            let size = popover ? NSSize(width: 332, height: 240) : NSSize(width: 740, height: 540)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = popover ? L10n.appName : L10n.windowDashboard
            window.isReleasedWhenClosed = false
            if popover {
                window.contentView = NSHostingView(rootView: DevicePopoverView(store: store))
            } else {
                window.contentView = NSHostingView(rootView: DashboardView(store: store))
            }
            let menu = NSMenu()
            let item = NSMenuItem()
            let submenu = NSMenu()
            submenu.addItem(NSMenuItem(title: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            item.submenu = submenu
            menu.addItem(item)
            NSApp.mainMenu = menu
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
        NSApp.run()
    }

}
