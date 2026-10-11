import SwiftUI

struct AboutPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.aboutProduct)
                    .font(.headline)
                Text(L10n.unofficial)
                    .font(.callout)
                Text(L10n.aboutVersion(AppRelease.version, AppRelease.build))
                    .foregroundStyle(.secondary)
                Text(L10n.aboutDeveloped(AppRelease.developed))
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.aboutWhatsNew)
                    .font(.headline)
                    .foregroundStyle(.primary)
                ForEach(AppRelease.notes, id: \.self) { note in
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.aboutSupported)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(MouseSupport.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(MouseSupport.families) { family in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(family.name)
                            .font(.callout)
                        Text(family.models)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
