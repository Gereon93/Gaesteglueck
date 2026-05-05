#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// MARK: - Array safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Enrichment Wizard

struct EnrichmentWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var currentGroupIndex = 0
    @State private var newTagName = ""
    @State private var newTagCategory: TagCategory = .friendGroup

    private var registrationGroups: [[Guest]] {
        let grouped = Dictionary(grouping: guests.filter { $0.registrationGroup != nil },
                                 by: { $0.registrationGroup! })
        let soloGuests = guests.filter { $0.registrationGroup == nil }
        var groups = Array(grouped.values).sorted { ($0.first?.fullName ?? "") < ($1.first?.fullName ?? "") }
        groups += soloGuests.map { [$0] }
        return groups
    }

    private var currentGroup: [Guest]? {
        registrationGroups[safe: currentGroupIndex]
    }

    private var progress: Double {
        guard !registrationGroups.isEmpty else { return 1 }
        return Double(currentGroupIndex) / Double(registrationGroups.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: progress)
                    .padding()

                HStack {
                    Text("Gruppe \(currentGroupIndex + 1) von \(registrationGroups.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                if let group = currentGroup {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(group) { guest in
                                GuestEnrichmentCard(guest: guest, allTags: tags) { newName, category in
                                    createAndAssignTag(name: newName, category: category, to: guest)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView("Alle Gruppen bearbeitet", systemImage: "checkmark.circle.fill")
                }

                Divider()

                HStack {
                    Button("Zurück") {
                        if currentGroupIndex > 0 { currentGroupIndex -= 1 }
                    }
                    .disabled(currentGroupIndex == 0)

                    Spacer()

                    if currentGroupIndex < registrationGroups.count - 1 {
                        Button("Weiter") {
                            currentGroupIndex += 1
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Fertig") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Gäste anreichern")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private func createAndAssignTag(name: String, category: TagCategory, to guest: Guest) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing = tags.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            if !existing.guestIDs.contains(guest.id) {
                existing.guestIDs.append(guest.id)
            }
        } else {
            let tag = Tag(name: trimmed, category: category)
            tag.guestIDs = [guest.id]
            modelContext.insert(tag)
        }
    }
}

// MARK: - Guest Enrichment Card

struct GuestEnrichmentCard: View {
    @Bindable var guest: Guest
    let allTags: [Tag]
    let onCreateTag: (String, TagCategory) -> Void

    @State private var newTagName = ""
    @State private var newTagCategory: TagCategory = .friendGroup

    private var guestTags: [Tag] {
        allTags.filter { $0.guestIDs.contains(guest.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(guest.fullName)
                .font(.headline)

            // Partner assignment
            Picker("Partner", selection: $guest.partnerAssignment) {
                ForEach(PartnerAssignment.allCases) { pa in
                    Text(pa.rawValue).tag(pa)
                }
            }
            .pickerStyle(.segmented)

            // Age category
            Picker("Altersgruppe", selection: $guest.ageCategory) {
                ForEach(AgeCategory.allCases) { ac in
                    Text(ac.rawValue).tag(ac)
                }
            }
            .pickerStyle(.segmented)

            // Family role
            Picker("Rolle", selection: $guest.familyRole) {
                Text("Keine Angabe").tag(nil as FamilyRole?)
                ForEach(FamilyRole.allCases) { role in
                    Text(role.rawValue).tag(role as FamilyRole?)
                }
            }

            // Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags").font(.subheadline).foregroundStyle(.secondary)

                if !guestTags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(guestTags) { tag in
                            HStack(spacing: 4) {
                                Text(tag.name)
                                    .font(.caption)
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: tag.color).opacity(0.2))
                            .foregroundStyle(Color(hex: tag.color))
                            .clipShape(Capsule())
                            .onTapGesture {
                                tag.guestIDs.removeAll { $0 == guest.id }
                            }
                        }
                    }
                }

                HStack {
                    TextField("Neuer Tag-Name", text: $newTagName)
                        .onSubmit { submitNewTag() }
                    Picker("", selection: $newTagCategory) {
                        ForEach(TagCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .frame(width: 140)
                    Button("Hinzufügen") { submitNewTag() }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    private func submitNewTag() {
        onCreateTag(newTagName, newTagCategory)
        newTagName = ""
    }
}
#endif
