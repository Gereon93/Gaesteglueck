#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TagListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query private var guests: [Guest]
    @Query private var events: [Event]
    @State private var selectedTag: Tag?
    @State private var newTagName = ""
    @State private var newTagCategory: TagCategory = .friendGroup
    @State private var showingEnrichment = false
    @State private var showingGenerator = false

    private var groupedTags: [(TagCategory, [Tag])] {
        let grouped = Dictionary(grouping: tags, by: \.category)
        return TagCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        NavigationSplitView {
            List {
                if tags.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Noch keine Tags", systemImage: "tag")
                                .font(.headline)
                            Text("Tags entstehen oft beim Anreichern — die App schlägt Gruppen aus euren Anmeldungen vor. Du kannst aber auch jetzt schon eigene anlegen.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                if !guests.isEmpty {
                                    Button {
                                        showingGenerator = true
                                    } label: {
                                        Label("Tags automatisch generieren", systemImage: "sparkles")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                    Button {
                                        showingEnrichment = true
                                    } label: {
                                        Label("Gäste anreichern", systemImage: "wand.and.sparkles")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.regular)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                ForEach(groupedTags, id: \.0) { category, categoryTags in
                    Section(category.rawValue) {
                        ForEach(categoryTags) { tag in
                            // Explizite Button-Zeile statt List(selection:)+.tag —
                            // SwiftData @Model-Selection war im macOS-Sidebar-List
                            // nicht zuverlässig anklickbar (Klick wurde geschluckt).
                            Button {
                                selectedTag = tag
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: tag.color))
                                        .frame(width: 10, height: 10)
                                        .saturation(tag.isActive ? 1.0 : 0.3)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    if let pa = tag.partnerAssignment {
                                        partnerBadge(pa)
                                    }
                                    Spacer()
                                    Text("\(tag.guestCount)")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                    Button {
                                        tag.isActive.toggle()
                                    } label: {
                                        Image(systemName: tag.isActive ? "checkmark.circle.fill" : "circle.slash")
                                            .foregroundStyle(tag.isActive ? Tokens.Colors.sage : Tokens.Colors.ink4)
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.borderless)
                                    .help(tag.isActive ? "Tag deaktivieren" : "Tag aktivieren")
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .opacity(tag.isActive ? 1.0 : 0.45)
                            .saturation(tag.isActive ? 1.0 : 0.4)
                            .listRowBackground(selectedTag?.id == tag.id ? Color.accentColor.opacity(0.2) : nil)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(tag)
                                    if selectedTag?.id == tag.id { selectedTag = nil }
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingGenerator = true
                    } label: {
                        Label("Auto-Tags", systemImage: "sparkles")
                    }
                    .help("Tags per KI aus Beziehungs-Beschreibung erzeugen")
                }
            }
            .sheet(isPresented: $showingEnrichment) {
                EnrichmentWizardView()
            }
            .sheet(isPresented: $showingGenerator) {
                TagGeneratorView()
            }
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

    @ViewBuilder
    private func partnerBadge(_ pa: PartnerAssignment) -> some View {
        Text(pa.displayName(for: events.first))
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(pa.color.opacity(0.18))
            .foregroundStyle(pa.color)
            .clipShape(Capsule())
    }
}
#endif
