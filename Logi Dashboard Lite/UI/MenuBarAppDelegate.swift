import AppKit
import SwiftUI

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    private let store: DeviceStore
    private(set) var statusItem: NSStatusItem?
    let popover = NSPopover()
    private var labelView: StatusItemLabelView?

    init(store: DeviceStore? = nil) {
        self.store = store ?? DeviceStore()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel(L10n.appName)

        let label = StatusItemLabelView(rootView: MenuBarLabel(store: store))
        label.onSizeChange = { [weak self] in self?.resizeLabel() }
        button.addSubview(label)
        labelView = label
        resizeLabel()

        popover.behavior = .transient
        // Closing before showing a context menu must finish immediately.
        popover.animates = false
        let panel = NSHostingController(rootView: DevicePopoverView(store: store))
        panel.sizingOptions = [.preferredContentSize]
        popover.contentViewController = panel
        popover.contentSize = panel.view.fittingSize

        MenuBarContextMenu.shared.openAbout = { [weak self] in
            guard let self else { return }
            self.popover.close()
            self.store.showsAbout = true
            DashboardWindowController.shared.show(store: self.store)
        }
        MenuBarContextMenu.shared.openSettings = { [weak self] in
            self?.popover.close()
            SettingsWindowController.shared.show()
        }
        MenuBarContextMenu.shared.install()
        store.start()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        handleClick(type: event?.type ?? .leftMouseUp, controlPressed: event?.modifierFlags.contains(.control) == true)
    }

    func handleClick(type: NSEvent.EventType, controlPressed: Bool) {
        guard let button = statusItem?.button else { return }
        if type == .rightMouseUp || (type == .leftMouseUp && controlPressed) {
            popover.close()
            let menu = MenuBarContextMenu.shared.makeMenu()
            // Let the status item position its own menu, including when macOS
            // expands an automatically hidden menu bar. A menu-backed click
            // is handled by AppKit rather than our left-click action.
            guard let item = statusItem else { return }
            item.menu = menu
            defer {
                item.menu = nil
                button.target = self
                button.action = #selector(statusItemClicked(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            button.performClick(nil)
        } else if type == .leftMouseUp {
            if popover.isShown {
                popover.close()
            } else {
                NSApp.activate()
                // The model may have finished scanning since initial creation.
                // Resolve the current content size before positioning the panel.
                if let view = popover.contentViewController?.view {
                    view.layoutSubtreeIfNeeded()
                    popover.contentSize = view.fittingSize
                }
                let bottomEdge: NSRectEdge = button.isFlipped ? .maxY : .minY
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: bottomEdge)
            }
        }
    }

    private func resizeLabel() {
        guard let item = statusItem, let button = item.button, let label = labelView else { return }
        let width = ceil(label.fittingSize.width)
        let length = max(24, width + 12)
        if item.length != length { item.length = length }
        let frame = button.bounds.insetBy(dx: 6, dy: 0)
        if label.frame != frame { label.frame = frame }
        label.autoresizingMask = [.width, .height]
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }
}

/// The status button owns mouse events; embedded SwiftUI content is display-only.
@MainActor
private final class StatusItemLabelView: NSHostingView<MenuBarLabel> {
    var onSizeChange: (() -> Void)?
    private var resizePending = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        guard !resizePending else { return }
        resizePending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.resizePending = false
            self.onSizeChange?()
        }
    }
}
