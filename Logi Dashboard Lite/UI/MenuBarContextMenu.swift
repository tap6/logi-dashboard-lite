import AppKit
import ObjectiveC

@MainActor
final class MenuBarContextMenu: NSObject {
    static let shared = MenuBarContextMenu()

    var openAbout: () -> Void = {}
    var openSettings: () -> Void = {}

    private var monitor: Any?
    private var isShowing = false
    private var pending = false
    private var armedButtons = Set<ObjectIdentifier>()

    func install() {
        installQuitShortcut()
        armStatusButtons()
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            let isContextClick = event.type == .rightMouseDown || event.modifierFlags.contains(.control)
            guard isContextClick, let item = self.statusItem(atScreenPoint: NSEvent.mouseLocation) else {
                return event
            }
            self.scheduleShow(item)
            return nil
        }
    }

    func show(from button: NSStatusBarButton) {
        guard let item = statusItem(for: button) else { return }
        show(statusItem: item)
    }

    private func scheduleShow(_ item: NSStatusItem) {
        guard !pending, !isShowing else { return }
        pending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pending = false
            self.show(statusItem: item)
        }
    }

    private func show(statusItem: NSStatusItem) {
        guard !isShowing else { return }
        isShowing = true
        defer { isShowing = false }

        closePopoverIfNeeded()
        let menu = makeMenu()
        statusItem.popUpMenu(menu)
    }

    private func closePopoverIfNeeded() {
        let open = NSApp.windows.contains { $0.className.contains("MenuBarExtraWindow") && $0.isVisible }
        guard open, let button = statusItems().first?.button else { return }
        button.performClick(nil)
    }

    private func statusItem(atScreenPoint point: NSPoint) -> NSStatusItem? {
        for item in statusItems() {
            guard let button = item.button, let window = button.window else { continue }
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            if rect.contains(point) { return item }
        }
        return nil
    }

    private func statusItem(for button: NSStatusBarButton) -> NSStatusItem? {
        statusItems().first { $0.button === button }
    }

    private func statusItems() -> [NSStatusItem] {
        NSApp.windows.compactMap { window in
            guard window.className.contains("NSStatusBarWindow") else { return nil }
            return window.value(forKey: "statusItem") as? NSStatusItem
        }
    }

    private func armStatusButtons() {
        for item in statusItems() {
            guard let button = item.button else { continue }
            arm(button)
        }
    }

    private func arm(_ button: NSStatusBarButton) {
        let identity = ObjectIdentifier(button)
        guard armedButtons.insert(identity).inserted else { return }
        guard let base = object_getClass(button) else { return }
        let subclassName = "LogiStatusButton_\(NSStringFromClass(base))"
        let subclass: AnyClass
        if let existing = NSClassFromString(subclassName) {
            subclass = existing
        } else {
            guard let pair = objc_allocateClassPair(base, subclassName, 0) else { return }
            let block: @convention(block) (AnyObject, NSEvent) -> Void = { obj, _ in
                MainActor.assumeIsolated {
                    guard let button = obj as? NSStatusBarButton else { return }
                    MenuBarContextMenu.shared.show(from: button)
                }
            }
            class_addMethod(
                pair,
                #selector(NSView.rightMouseDown(with:)),
                imp_implementationWithBlock(block),
                "v@:@"
            )
            objc_registerClassPair(pair)
            subclass = pair
        }
        object_setClass(button, subclass)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let about = NSMenuItem(title: L10n.aboutMenu, action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let settings = NSMenuItem(title: L10n.settingsMenu, action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let updates = NSMenuItem(title: L10n.checkForUpdates, action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    @objc private func showAbout() {
        openAbout()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func checkForUpdates() {
        guard let url = URL(string: "https://github.com/tap6/logi-dashboard-lite/releases") else { return }
        NSWorkspace.shared.open(url)
    }

    private func installQuitShortcut() {
        guard NSApp.mainMenu == nil else { return }
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let main = NSMenu()
        main.addItem(appItem)
        NSApp.mainMenu = main
    }
}
