#if canImport(SwiftUI)
import SwiftUI

struct GuestRowView: View {
    let guest: Guest

    var body: some View {
        HStack {
            Circle()
                .fill(guest.side.color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(guest.name)
                        .font(.body)
                    if guest.isChild {
                        Image(systemName: "figure.child")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    if let groupLabel = guest.groupLabel {
                        Text(groupLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let role = guest.familyRole {
                        Text(role.rawValue)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            HStack(spacing: 2) {
                Text(guest.dietaryPreference.badge)
                    .font(.caption)
                if !guest.allergies.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help(guest.allergies)
                }
            }
            Text(guest.rsvpStatus.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(guest.rsvpStatus.color.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}
#endif
