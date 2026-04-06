#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct GuestRowView: View {
    let guest: Guest
    var tags: [Tag] = []

    private var guestTags: [Tag] {
        tags.filter { $0.guestIDs.contains(guest.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // Partner badge
                Text(guest.partnerAssignment.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(guest.partnerAssignment.color.opacity(0.2))
                    .foregroundStyle(guest.partnerAssignment.color)
                    .clipShape(Capsule())

                Text(guest.fullName)
                    .font(.body)

                // Age badge if not adult
                if guest.ageCategory != .adult {
                    Label(guest.ageCategory.rawValue, systemImage: guest.ageCategory.icon)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                // Dietary info
                if guest.dietaryChoice != "Fleisch" {
                    Text(guest.dietaryChoice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Intolerance warning
                if guest.hasIntolerances {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help(guest.intolerances.joined(separator: ", "))
                }
            }

            // Tags
            if !guestTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(guestTags) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: tag.color).opacity(0.2))
                                .foregroundStyle(Color(hex: tag.color))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
#endif
