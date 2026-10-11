import AppKit
import SwiftUI

struct DevicePopoverView: View {
    var store: DeviceStore
    @AppStorage(AppPreference.lowBatteryThreshold) private var lowThreshold = 15.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsProfileSwitcher {
                PopoverToolbar(store: store)
                Divider()
            }
            PopoverBody(store: store, lowThreshold: Int(lowThreshold))
            Divider()
            PopoverFooter(store: store, openDashboard: openDashboard)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear(perform: refresh)
    }

    private func openDashboard() {
        DashboardWindowController.shared.show(store: store)
    }

    private var showsProfileSwitcher: Bool {
        store.devices.contains { $0.controls?.canSwitchProfile == true && $0.link == .online }
    }

    private func refresh() {
        Task { await store.refresh() }
    }
}

#Preview("在线") {
    DevicePopoverView(store: .preview([.previewOnline]))
}

#Preview("电量偏低") {
    DevicePopoverView(store: .preview([.previewLow]))
}

#Preview("充电") {
    DevicePopoverView(store: .preview([.previewCharging]))
}

#Preview("休眠") {
    DevicePopoverView(store: .preview([.previewAsleep]))
}

#Preview("未连接") {
    DevicePopoverView(store: .preview([], phase: .noHardware))
}

#Preview("多套配置") {
    var device = TrackedDevice.previewOnline
    device.controls = .previewMultiple
    return DevicePopoverView(store: .preview([device]))
}
