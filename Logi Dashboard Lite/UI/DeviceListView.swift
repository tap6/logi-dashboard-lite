import SwiftUI

struct DeviceListView: View {
    var devices: [TrackedDevice]
    var lowThreshold: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                if index > 0 {
                    Divider()
                }
                DeviceCardView(device: device, lowThreshold: lowThreshold)
            }
        }
    }
}
