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
        Task { @MainActor in await checkMenuBar(notification, store: store) }
    }

    private func checkMenuBar(_ notification: Notification, store: DeviceStore) async {
        let menuApp = MenuBarAppDelegate(store: store)
        store.devices = []
        store.phase = .loading
        menuApp.applicationDidFinishLaunching(notification)
        store.devices = [.previewOnline]
        store.phase = .ready
        try? await Task.sleep(for: .milliseconds(100))
        var firstVisibleTop: CGFloat?
        let showObserver = NotificationCenter.default.addObserver(
            forName: NSPopover.didShowNotification, object: menuApp.popover, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                firstVisibleTop = Self.checkPanelPosition(menuApp).maxY
            }
        }
        var menuCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { notification in
            MainActor.assumeIsolated {
                precondition(!menuApp.popover.isShown, "Context menu must never coexist with the mouse panel")
                menuCount += 1
                guard let menu = notification.object as? NSMenu else { return }
                let timer = Timer(timeInterval: 0.05, repeats: false) { _ in
                    MainActor.assumeIsolated { menu.cancelTrackingWithoutAnimation() }
                }
                RunLoop.main.add(timer, forMode: .eventTracking)
            }
        }
        menuApp.handleClick(type: .rightMouseUp, controlPressed: false)
        precondition(menuCount == 1 && !menuApp.popover.isShown)
        menuApp.handleClick(type: .leftMouseUp, controlPressed: false)
        try? await Task.sleep(for: .milliseconds(100))
        precondition(menuApp.popover.isShown, "Left click must open the panel")
        let initialPanel = Self.checkPanelPosition(menuApp)
        precondition(firstVisibleTop != nil, "First visible position must be checked")
        precondition(abs(initialPanel.maxY - firstVisibleTop!) <= 1, "Panel must not jump after appearing")
        var expanded = TrackedDevice.previewOnline
        expanded.controls = .previewMultiple
        store.devices = [expanded]
        try? await Task.sleep(for: .milliseconds(200))
        let expandedPanel = Self.checkPanelPosition(menuApp)
        precondition(expandedPanel.height > initialPanel.height, "Panel must resize with profile controls")
        precondition(abs(expandedPanel.maxY - initialPanel.maxY) <= 1, "Content growth must keep the panel anchored below the menu bar")
        menuApp.handleClick(type: .rightMouseUp, controlPressed: false)
        precondition(menuCount == 2 && !menuApp.popover.isShown)
        menuApp.handleClick(type: .leftMouseUp, controlPressed: false)
        try? await Task.sleep(for: .milliseconds(100))
        precondition(menuApp.popover.isShown)
        menuApp.handleClick(type: .leftMouseUp, controlPressed: true)
        precondition(menuCount == 3 && !menuApp.popover.isShown)
        menuApp.handleClick(type: .leftMouseUp, controlPressed: false)
        try? await Task.sleep(for: .milliseconds(100))
        precondition(menuApp.popover.isShown)
        menuApp.handleClick(type: .leftMouseUp, controlPressed: false)
        precondition(!menuApp.popover.isShown, "Second left click must close the panel")
        NotificationCenter.default.removeObserver(observer)
        NotificationCenter.default.removeObserver(showObserver)
        menuApp.applicationWillTerminate(notification)
        SettingsWindowController.shared.show()
        precondition(SettingsWindowController.shared.window?.isVisible == true)
        SettingsWindowController.shared.window?.close()
        print("Menu bar runtime smoke check passed: left, right, open-panel right, Control-click, settings, first-show position and dynamic sizing.")
        NSApp.terminate(nil)
    }

    private static func checkPanelPosition(_ menuApp: MenuBarAppDelegate) -> NSRect {
        guard let button = menuApp.statusItem?.button, let statusWindow = button.window,
              let panelWindow = menuApp.popover.contentViewController?.view.window else {
            fatalError("Visible panel must have an anchor and a window")
        }
        let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        precondition(panelWindow.frame.maxY <= anchor.minY + 1, "Panel must open below the status button")
        return panelWindow.frame
    }
}

@main
struct WindowSmoke {
    static func main() {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = WindowSmokeDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
