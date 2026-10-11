import SwiftUI

struct PopoverBody: View {
    var store: DeviceStore
    var lowThreshold: Int

    var body: some View {
        switch store.phase {
        case .loading:
            PopoverPlaceholder(
                symbolName: "computermouse",
                title: L10n.popoverLoadingTitle,
                message: L10n.popoverLoadingMessage,
                showsSpinner: true
            )
        case .noHardware:
            PopoverPlaceholder(
                symbolName: "computermouse",
                title: L10n.noMouse,
                message: L10n.popoverNoHardwareMessage
            )
        case .receiverOnly:
            PopoverPlaceholder(
                symbolName: "computermouse",
                title: L10n.popoverReceiverTitle,
                message: L10n.popoverReceiverMessage
            )
        case .unavailable:
            PopoverPlaceholder(
                symbolName: "exclamationmark.triangle",
                title: L10n.popoverUnavailableTitle,
                message: L10n.popoverUnavailableMessage
            )
        case .ready:
            DeviceListView(devices: store.devices, lowThreshold: lowThreshold)
        }
    }
}
