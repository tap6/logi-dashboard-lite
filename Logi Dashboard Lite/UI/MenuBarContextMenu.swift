import AppKit

@MainActor
final class MenuBarContextMenu: NSObject {
    static let shared = MenuBarContextMenu()

    var openAbout: () -> Void = {}
    var openSettings: () -> Void = {}

    func install() {
        installQuitShortcut()
    }

    func makeMenu() -> NSMenu {
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
