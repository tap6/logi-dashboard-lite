import SwiftUI

struct PopoverPlaceholder: View {
    var symbolName: String
    var title: String
    var message: String
    var showsSpinner: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            if showsSpinner {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
