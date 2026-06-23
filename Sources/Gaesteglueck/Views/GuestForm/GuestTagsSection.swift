#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Tag-Auswahl im Gast-Formular. `selectedTagIDs` lebt im Parent (wird beim
/// Speichern abgeglichen), daher als Binding.
struct GuestTagsSection: View {
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @Binding var selectedTagIDs: Set<UUID>

    var body: some View {
        Section("Tags") {
            if allTags.isEmpty {
                Text("Noch keine Tags angelegt — über Beziehungen → Auto-Tags erstellen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                tagsByCategory
            }
        }
    }

    @ViewBuilder
    private var tagsByCategory: some View {
        // Tags sind nach Kategorie gruppiert für bessere Übersicht
        let grouped = Dictionary(grouping: allTags, by: \.category)
        ForEach(TagCategory.allCases) { cat in
            if let tagsInCat = grouped[cat], !tagsInCat.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cat.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 100), spacing: 6, alignment: .leading)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(tagsInCat) { tag in
                            tagChip(tag)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isSelected = selectedTagIDs.contains(tag.id)
        return Button {
            if isSelected {
                selectedTagIDs.remove(tag.id)
            } else {
                selectedTagIDs.insert(tag.id)
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: tag.color))
                    .frame(width: 7, height: 7)
                Text(tag.name)
                    .font(.system(size: 11.5, design: .rounded))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color(hex: tag.color).opacity(0.22) : Color.gray.opacity(0.08))
            .foregroundStyle(isSelected ? Color(hex: tag.color) : .primary)
            .overlay(
                Capsule().strokeBorder(isSelected ? Color(hex: tag.color) : .clear, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
#endif
