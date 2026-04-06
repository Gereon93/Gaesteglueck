#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TagListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var selectedTag: Tag?
    @State private var newTagName = ""
    @State private var newTagCategory: TagCategory = .friendGroup

    private var groupedTags: [(TagCategory, [Tag])] {
        let grouped = Dictionary(grouping: tags, by: \.category)
        return TagCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTag) {
                ForEach(groupedTags, id: \.0) { category, categoryTags in
                    Section(category.rawValue) {
                        ForEach(categoryTags) { tag in
                            HStack {
                                Circle()
                                    .fill(Color(hex: tag.color))
                                    .frame(width: 10, height: 10)
                                Text(tag.name)
                                Spacer()
                                Text("\(tag.guestCount)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .tag(tag as Tag?)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(categoryTags[index])
                            }
                        }
                    }
                }

                Section("Neuen Tag erstellen") {
                    TextField("Tag-Name", text: $newTagName)
                    Picker("Kategorie", selection: $newTagCategory) {
                        ForEach(TagCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    Button("Tag erstellen") {
                        createTag()
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Tags & Gruppen")
            .listStyle(.sidebar)
        } detail: {
            if let tag = selectedTag {
                TagDetailView(tag: tag)
            } else {
                ContentUnavailableView("Kein Tag gewählt", systemImage: "tag", description: Text("Wähle einen Tag aus der Liste."))
            }
        }
    }

    private func createTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(name: trimmed, category: newTagCategory)
        modelContext.insert(tag)
        selectedTag = tag
        newTagName = ""
    }
}
#endif
