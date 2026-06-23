#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// MARK: - Import Row Card

struct ImportRowCard: View {
    let row: RegistrationRow
    let state: ImportPreviewView.RowState
    var isAutoSkipped: Bool = false
    let onUpdate: ([ImportedGuest]) -> Void
    let onAccept: () -> Void
    let onSkip: () -> Void

    @Query private var existingGuests: [Guest]
    @State private var editingIndex: Int? = nil

    private func matchType(for g: ImportedGuest) -> ImportMatcher.MatchType {
        ImportMatcher.classify(guest: g, in: row, among: existingGuests)
    }

    private var rawText: String {
        var parts: [String] = []
        parts.append(row.familyName)
        if !row.guestDetails.isEmpty { parts.append(row.guestDetails) }
        if !row.funFacts.isEmpty { parts.append(row.funFacts) }
        if !row.notes.isEmpty { parts.append(row.notes) }
        return parts.joined(separator: " · ")
    }

    private var statusBadge: (text: String, fg: Color, bg: Color)? {
        if isAutoSkipped {
            return ("Unverändert", Tokens.Colors.sage, Tokens.Colors.sage.opacity(0.18))
        }
        switch state {
        case .parsing: return ("Parst…", Tokens.Colors.ink3, Tokens.Colors.bg2)
        case .parsed: return nil
        case .fallback: return ("Prüfen", Tokens.Colors.warn, Tokens.Colors.warnSoft)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Original
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Tokens.Colors.bg3)
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ORIGINAL-ANMELDUNG")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .tracking(0.5)
                    Text("\u{201E}\(rawText)\u{201C}")
                        .font(Tokens.Typography.display(size: 14.5, italic: true))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if let badge = statusBadge {
                    Text(badge.text)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(badge.fg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badge.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Tokens.Colors.surface)

            Divider().background(Tokens.Colors.line)

            // Parsing-State / Gäste
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Colors.accent)
                    Text("Wir lesen daraus:")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.accent)
                        .tracking(0.3)
                }

                switch state {
                case .parsing:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("KI parst die Anmeldung…")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                case .parsed(let guests), .fallback(let guests, _):
                    if guests.isEmpty {
                        Text("Keine Gäste extrahiert.")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(Array(guests.enumerated()), id: \.offset) { idx, g in
                            parsedGuestRow(g, index: idx)
                        }
                    }

                    Button {
                        var updated = guests
                        let lastName = guests.last?.lastName ?? row.familyName
                        updated.append(ImportedGuest(
                            firstName: "Neuer Gast",
                            lastName: lastName,
                            dietaryChoice: "Fleisch",
                            intolerances: [],
                            ageCategory: .adult,
                            funFact: "",
                            notes: ""
                        ))
                        onUpdate(updated)
                        editingIndex = updated.count - 1
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Person hinzufügen")
                        }
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    if case .fallback(_, let reason) = state {
                        Text("Hinweis: " + reason)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.warn)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                    }
                }

                HStack(spacing: 8) {
                    Spacer()
                    Button("Überspringen") { onSkip() }
                        .warmButton(.ghost, size: .sm)
                    Button {
                        onAccept()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text("Übernehmen")
                        }
                    }
                    .warmButton(.primary, size: .sm)
                    .disabled({
                        if case .parsing = state { return true }
                        return state.guests.isEmpty
                    }())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .cardShadow()
        .sheet(item: Binding<EditingTarget?>(
            get: {
                guard let idx = editingIndex,
                      let guest = state.guests[safe: idx] else { return nil }
                return EditingTarget(index: idx, guest: guest)
            },
            set: { editingIndex = $0?.index }
        )) { target in
            ImportGuestEditSheet(
                guest: target.guest,
                onSave: { updated in
                    var list = state.guests
                    if list.indices.contains(target.index) {
                        list[target.index] = updated
                        onUpdate(list)
                    }
                    editingIndex = nil
                },
                onDelete: {
                    var list = state.guests
                    if list.indices.contains(target.index) {
                        list.remove(at: target.index)
                        onUpdate(list)
                    }
                    editingIndex = nil
                },
                onCancel: {
                    editingIndex = nil
                }
            )
        }
    }

    private struct EditingTarget: Identifiable {
        let index: Int
        let guest: ImportedGuest
        var id: Int { index }
    }

    private func parsedGuestRow(_ g: ImportedGuest, index: Int) -> some View {
        let match = matchType(for: g)
        let diffs = diffFields(for: g, match: match)
        return Button {
            editingIndex = index
        } label: {
            HStack(spacing: 12) {
                Avatar(
                    name: g.firstName.isEmpty ? g.lastName : g.firstName + " " + g.lastName,
                    size: 32,
                    tag: .family,
                    diet: dietBadge(for: g)
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(displayName(g))
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink)
                        matchBadge(for: match)
                    }
                    Text(detailLine(g))
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .lineLimit(2)
                    if !diffs.isEmpty {
                        diffStrip(diffs)
                    }
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Colors.ink4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Tokens.Colors.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func diffFields(for g: ImportedGuest, match: ImportMatcher.MatchType) -> [ImportDiffField] {
        guard match == .updateBySource,
              let existing = ImportMatcher.findExisting(guest: g, in: row, among: existingGuests) else {
            return []
        }
        return ImportMatcher.diff(parsed: g, existing: existing)
    }

    @ViewBuilder
    private func diffStrip(_ diffs: [ImportDiffField]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(diffs, id: \.label) { d in
                HStack(spacing: 4) {
                    Text(d.label + ":")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                    Text(d.oldValue)
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundStyle(Tokens.Colors.ink3)
                    Text(d.newValue)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.sage)
                }
                .lineLimit(1)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func matchBadge(for match: ImportMatcher.MatchType) -> some View {
        switch match {
        case .new:
            EmptyView()
        case .updateBySource:
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9))
                Text("wird aktualisiert")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Tokens.Colors.sage)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Tokens.Colors.sageTint)
            .clipShape(Capsule())
        case .nameMatchOnly:
            HStack(spacing: 3) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 9))
                Text("Name existiert schon — neu anlegen")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Tokens.Colors.warn)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Tokens.Colors.warnSoft)
            .clipShape(Capsule())
        }
    }

    private func displayName(_ g: ImportedGuest) -> String {
        let combined = "\(g.firstName) \(g.lastName)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? "(Name fehlt)" : combined
    }

    private func detailLine(_ g: ImportedGuest) -> String {
        var parts: [String] = []
        parts.append(g.dietaryChoice)
        if !g.intolerances.isEmpty {
            parts.append("Allergie: " + g.intolerances.joined(separator: ", "))
        }
        if g.ageCategory != .adult {
            parts.append(g.ageCategory.rawValue)
        }
        if !g.tagNames.isEmpty {
            let tags = g.tagNames.prefix(3).joined(separator: ", ")
            let suffix = g.tagNames.count > 3 ? " +\(g.tagNames.count - 3)" : ""
            parts.append("Tags: " + tags + suffix)
        }
        if !g.funFact.isEmpty {
            let fact = g.funFact.count > 60 ? String(g.funFact.prefix(60)) + "…" : g.funFact
            parts.append("\u{201E}" + fact + "\u{201C}")
        }
        return parts.joined(separator: " · ")
    }

    private func dietBadge(for g: ImportedGuest) -> Avatar.DietBadge? {
        if !g.intolerances.isEmpty { return .allergie }
        switch g.dietaryChoice.lowercased() {
        case "vegetarisch": return .veg
        case "vegan": return .vegan
        default: return nil
        }
    }
}

// MARK: - Safe array access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
