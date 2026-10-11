import SwiftUI

struct PopoverFooter: View {
    var store: DeviceStore
    var openDashboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let lastUpdated = store.lastUpdated {
                    Text(lastUpdated, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(L10n.refresh, systemImage: "arrow.clockwise", action: refresh)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(store.isRefreshing)
                    .help(L10n.refresh)
                Button(L10n.dashboard, systemImage: "slider.horizontal.3", action: openDashboard)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help(L10n.dashboard)
            }
            Text(store.controlNote ?? (store.devices.contains { $0.controls != nil }
                ? L10n.popoverFooterControls
                : L10n.popoverFooterReadOnly))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func refresh() {
        Task { await store.refresh() }
    }
}
