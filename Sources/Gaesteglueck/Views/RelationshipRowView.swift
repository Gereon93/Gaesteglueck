#if canImport(SwiftUI)
import SwiftUI

struct RelationshipRowView: View {
    let relationship: Relationship
    let allGuests: [Guest]

    private var personA: Guest? {
        allGuests.first { $0.id == relationship.personAID }
    }

    private var personB: Guest? {
        allGuests.first { $0.id == relationship.personBID }
    }

    var body: some View {
        HStack {
            Image(systemName: relationship.type.icon)
                .foregroundStyle(relationship.type.color)
                .frame(width: 30)
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(personA?.name ?? "Unbekannt")
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(personB?.name ?? "Unbekannt")
                }
                .font(.body)
                Text(relationship.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
