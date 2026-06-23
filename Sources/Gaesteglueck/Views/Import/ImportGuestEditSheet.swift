#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// MARK: - Edit Sheet

struct ImportGuestEditSheet: View {
    let guest: ImportedGuest
    let onSave: (ImportedGuest) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var dietaryChoice: String = "Fleisch"
    @State private var intolerancesText: String = ""
    @State private var funFact: String = ""
    @State private var isChild: Bool = false
    @State private var selectedTagNames: Set<String> = []
    @State private var newTagInput: String = ""

    private static let dietaryOptions = ["Fleisch", "Vegetarisch", "Vegan"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Gast bearbeiten")
                    .font(Tokens.Typography.displayS)
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Korrigier was die KI falsch zusammengebaut hat — Vor- und Nachname, Menü, Allergien, Fun Fact.")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        labeledField("Vorname") {
                            TextField("Anna", text: $firstName)
                                .textFieldStyle(.roundedBorder)
                        }
                        labeledField("Nachname") {
                            TextField("Müller", text: $lastName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    labeledField("Menüwahl") {
                        Picker("", selection: $dietaryChoice) {
                            ForEach(Self.dietaryOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    labeledField("Unverträglichkeiten") {
                        TextField("Komma-getrennt, z.B. Nüsse, Laktose", text: $intolerancesText)
                            .textFieldStyle(.roundedBorder)
                    }

                    labeledField("Fun Fact") {
                        TextField("z.B. Hat einmal einen Yoga-Kurs für Hunde besucht", text: $funFact, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)
                    }

                    labeledField("Tags") {
                        VStack(alignment: .leading, spacing: 8) {
                            // Vorhandene Tags + neu hinzugefügte (lokal noch nicht gespeichert)
                            let combined = combinedTagDisplay
                            if !combined.isEmpty {
                                ChipFlow(spacing: 6) {
                                    ForEach(combined, id: \.self) { name in
                                        tagToggleChip(name: name)
                                    }
                                }
                            }
                            HStack(spacing: 6) {
                                TextField("Neuen Tag hinzufügen…", text: $newTagInput)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13, design: .rounded))
                                    .onSubmit { addNewTag() }
                                Button {
                                    addNewTag()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(canAddNewTag ? Tokens.Colors.accent : Tokens.Colors.ink4)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddNewTag)
                            }
                        }
                    }

                    Toggle("Ist ein Kind", isOn: $isChild)
                        .font(.system(size: 13, design: .rounded))
                        .padding(.top, 4)
                }
                .padding(24)
            }

            // Footer
            HStack(spacing: 8) {
                Button("Löschen", role: .destructive) {
                    onDelete()
                }
                .warmButton(.ghost)
                Spacer()
                Button("Abbrechen") { onCancel() }
                    .warmButton(.secondary)
                    .keyboardShortcut(.cancelAction)
                Button {
                    save()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Speichern")
                    }
                }
                .warmButton(.primary)
                .keyboardShortcut(.defaultAction)
                .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Tokens.Colors.bg2)
            .overlay(alignment: .top) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }
        }
        .frame(width: 560, height: 580)
        .background(Tokens.Colors.surface)
        .onAppear {
            firstName = guest.firstName
            lastName = guest.lastName
            dietaryChoice = guest.dietaryChoice
            intolerancesText = guest.intolerances.joined(separator: ", ")
            funFact = guest.funFact
            isChild = guest.ageCategory != .adult
            selectedTagNames = Set(guest.tagNames)
        }
    }

    private var combinedTagDisplay: [String] {
        // Bestehende DB-Tags + neue lokal gewählte, alphabetisch
        let existing = allTags.map(\.name)
        let union = Set(existing).union(selectedTagNames)
        return union.sorted()
    }

    private var canAddNewTag: Bool {
        let trimmed = newTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }

    private func addNewTag() {
        let trimmed = newTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedTagNames.insert(trimmed)
        newTagInput = ""
    }

    @ViewBuilder
    private func tagToggleChip(name: String) -> some View {
        let isSelected = selectedTagNames.contains(name)
        let kind: TagChip.Kind = tagKind(for: name)
        Button {
            if isSelected {
                selectedTagNames.remove(name)
            } else {
                selectedTagNames.insert(name)
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(kind.dotColor)
                    .frame(width: 6, height: 6)
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Tokens.Colors.accent)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isSelected ? Tokens.Colors.accentSoft : Tokens.Colors.bg2)
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Tokens.Colors.accent.opacity(0.3) : Tokens.Colors.line, lineWidth: 1)
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func tagKind(for name: String) -> TagChip.Kind {
        if let existing = allTags.first(where: { $0.name.lowercased() == name.lowercased() }) {
            switch existing.category {
            case .family: return .family
            case .friendGroup: return .friends
            case .role: return .role
            case .activity: return .activity
            case .work: return .work
            case .custom: return .custom
            }
        }
        // Heuristik für lokal neu angelegte Tags
        let lower = name.lowercased()
        if lower.contains("familie") || lower.contains("familien") { return .family }
        if lower.contains("trauzeug") { return .role }
        return .custom
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.4)
            content()
        }
    }

    private func save() {
        let intolerances = intolerancesText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let updated = ImportedGuest(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            dietaryChoice: dietaryChoice,
            intolerances: intolerances,
            ageCategory: isChild ? .child : .adult,
            funFact: funFact.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: "",
            tagNames: Array(selectedTagNames)
        )
        onSave(updated)
    }
}

// MARK: - Chip Flow Layout

private struct ChipFlow: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if rowWidth + s.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        totalHeight += rowHeight
        return CGSize(width: width.isFinite ? width : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
#endif
