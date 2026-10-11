import SwiftUI

@main
struct LogiDashboardLiteApp: App {
    @State private var store: DeviceStore

    init() {
        let store = DeviceStore()
        _store = State(initialValue: store)
        store.start()
    }

    var body: some Scene {
        MenuBarExtra {
            DevicePopoverView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }

        Window(Text(L10n.windowDashboard), id: "dashboard") {
            DashboardView(store: store)
        }
        .defaultSize(width: 740, height: 540)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
    }
}
