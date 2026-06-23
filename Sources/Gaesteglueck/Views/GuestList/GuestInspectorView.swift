#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S3 — rechter Inspector (300pt). Zeigt entweder das Detail des einzelnen
/// ausgewählten Gastes oder — bei Mehrfach-Auswahl — eine Übersicht mit
/// Bulk-Tag-Operationen. Mutiert Gäste/Tags direkt über den modelContext;
/// Auswahl- und Sheet-Zustand liegt als Binding beim Parent.
struct GuestInspectorView: View {
    @Environment(\.modelContext) private var modelContext
    let guests: [Guest]
    let tags: [Tag]
    let event: Event?
    @Binding var selectedGuestIDs: Set<UUID>
    @Binding var anchorGuestID: UUID?
    @Binding var editingGuest: Guest?
    @Binding var showingDeleteAlert: Bool

    private var selectedGuests: [Guest] {
        guests.filter { selectedGuestIDs.contains($0.id) }
    }

    private var primarySelectedGuest: Guest? {
        selectedGuests.count == 1 ? selectedGuests.first : nil
    }

    @ViewBuilder
    var body: some View {
        if selectedGuestIDs.count >= 2 {
            multiSelectInspector
        } else if let guest = primarySelectedGuest {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    inspectorHeader(guest)

                    InspectorSection("Tags") {
                        let guestTags = tags.filter { $0.guestIDs.contains(guest.id) }
                        if guestTags.isEmpty {
                            Text("Noch keine Tags")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        } else {
                            ChipFlowLayout(spacing: 5) {
                                ForEach(guestTags) { tag in
                                    TagChip(label: tag.name, kind: GuestDisplayFormatting.chipKind(for: tag.category), size: .sm)
                                }
                            }
                        }
                    }

                    InspectorSection("Sitzplan") {
                        if let table = guest.table {
                            HStack(spacing: 8) {
                                Circle().fill(Tokens.Colors.accent).frame(width: 8, height: 8)
                                Text(table.name)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Tokens.Colors.ink)
                            }
                            if guest.isPinned {
                                Text("Gepinnt — bleibt auch bei KI-Vorschlägen an diesem Tisch.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Tokens.Colors.ink2)
                                    .lineSpacing(2)
                                    .padding(.top, 4)
                            }
                            Button(guest.isPinned ? "Pin lösen" : "Anpinnen") {
                                guest.isPinned.toggle()
                            }
                            .warmButton(.secondary, size: .sm)
                            .padding(.top, 8)
                        } else {
                            Text("Noch keinem Tisch zugewiesen.")
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        }
                    }

                    InspectorSection("Familienrolle") {
                        familyRoleSummary(for: guest)
                    }

                    if !guest.notes.isEmpty {
                        InspectorSection("Notizen") {
                            Text(guest.notes)
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink2)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    InspectorSection("Menü & Allergien") {
                        VStack(alignment: .leading, spacing: 6) {
                            inspectorRow("Menüwahl", guest.dietaryChoice)
                            inspectorRow("Allergien", guest.hasIntolerances ? guest.intolerances.joined(separator: ", ") : "Keine")
                            if !guest.funFactDisplay.isEmpty {
                                inspectorRow("Fun Fact", guest.funFactDisplay)
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Bearbeiten") { editingGuest = guest }
                            .warmButton(.secondary, size: .sm)
                        Button("Löschen", role: .destructive) {
                            modelContext.delete(guest)
                            selectedGuestIDs.remove(guest.id)
                        }
                        .warmButton(.ghost, size: .sm)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Tokens.Colors.bg2)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 32))
                    .foregroundStyle(Tokens.Colors.ink4)
                Text("Wähle einen Gast")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                Text("Klick einen Gast in der Liste an, um Details zu sehen.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Colors.bg2)
        }
    }

    /// Tag-Mass-Operations für die aktuelle Mehrfach-Auswahl. Zwei Menüs:
    /// hinzufügen (alle Tags, gruppiert nach Kategorie) und entfernen
    /// (nur Tags die mindestens ein selektierter Gast aktuell hat).
    @ViewBuilder
    private var bulkTagControls: some View {
        let currentTags = tagsOnAnyOfSelection()
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                let grouped = Dictionary(grouping: tags, by: \.category)
                ForEach(TagCategory.allCases) { cat in
                    if let inCat = grouped[cat], !inCat.isEmpty {
                        Section(cat.rawValue) {
                            ForEach(inCat.sorted(by: { $0.name < $1.name })) { tag in
                                Button {
                                    addTagToSelection(tag)
                                } label: {
                                    HStack {
                                        Circle().fill(Color(hex: tag.color)).frame(width: 8, height: 8)
                                        Text(tag.name)
                                        if let pa = tag.partnerAssignment, pa != .unassigned {
                                            Text("· \(pa.compactDisplayName(for: event))")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                    Text("Tag hinzufügen…")
                }
                .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Tokens.Colors.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Tokens.Colors.line, lineWidth: 1))

            Menu {
                if currentTags.isEmpty {
                    Text("Keiner der Gäste hat aktuell Tags.")
                } else {
                    ForEach(currentTags.sorted(by: { $0.name < $1.name })) { tag in
                        Button {
                            removeTagFromSelection(tag)
                        } label: {
                            HStack {
                                Circle().fill(Color(hex: tag.color)).frame(width: 8, height: 8)
                                Text(tag.name)
                                Text("· \(membersInSelection(of: tag).count)/\(selectedGuestIDs.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "minus.circle")
                    Text("Tag entfernen…")
                }
                .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)
            .disabled(currentTags.isEmpty)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Tokens.Colors.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Tokens.Colors.line, lineWidth: 1))

            if !currentTags.isEmpty {
                Text("\(currentTags.count) Tag\(currentTags.count == 1 ? "" : "s") aktuell auf min. einem Gast — Anteil zeigt 'X/Y' (X von Y haben den Tag).")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tagsOnAnyOfSelection() -> [Tag] {
        tags.filter { tag in
            tag.guestIDs.contains(where: { selectedGuestIDs.contains($0) })
        }
    }

    private func membersInSelection(of tag: Tag) -> [UUID] {
        tag.guestIDs.filter { selectedGuestIDs.contains($0) }
    }

    private func addTagToSelection(_ tag: Tag) {
        // Bewusst KEIN Side-Auto-Derive beim Massen-Tag-Zuweisen — der
        // User markiert evtl. die "Schwiegermutter Alice" als Mitglied
        // eines neutralen Tags ohne damit ihre Zuordnung zu Alices Seite
        // ändern zu wollen. Side bleibt wie sie ist; ggf. einzeln im Edit-
        // Sheet anpassen.
        for id in selectedGuestIDs where !tag.guestIDs.contains(id) {
            tag.guestIDs.append(id)
        }
    }

    private func removeTagFromSelection(_ tag: Tag) {
        tag.guestIDs.removeAll { selectedGuestIDs.contains($0) }
    }

    /// Familienrolle + Seite in einer Zeile für den Inspector. „Vater von
    /// Bob", „Schwester von Alice", oder dezenter Hinweis wenn nichts
    /// gepflegt ist (mit Quick-Edit-Button).
    @ViewBuilder
    private func familyRoleSummary(for guest: Guest) -> some View {
        if let role = guest.familyRole {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Colors.ink3)
                Text(familyRoleLabel(role: role, guest: guest))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
            }
        } else {
            HStack(spacing: 6) {
                Text("Keine Familienrolle gesetzt")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                Spacer()
                Button("Setzen") { editingGuest = guest }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.accent)
            }
        }
    }

    private func familyRoleLabel(role: FamilyRole, guest: Guest) -> String {
        let side = guest.familyRolePartner ?? guest.partnerAssignment.optionalSelf
        if let side {
            return "\(role.rawValue) von \(side.compactDisplayName(for: event))"
        }
        return role.rawValue
    }

    private var multiSelectInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MEHRFACH AUSGEWÄHLT")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
                Text("\(selectedGuestIDs.count) Gäste")
                    .font(Tokens.Typography.displayS)
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Mit Shift+Klick erweiterst du die Auswahl, mit Cmd+Klick wechselst du einzelne. Drück Delete oder klick unten zum Löschen.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineSpacing(2)
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }

            InspectorSection("Auswahl-Übersicht") {
                let breakdown = selectionBreakdown
                VStack(alignment: .leading, spacing: 6) {
                    inspectorPropRow("Gepinnt", "\(breakdown.pinned)")
                    inspectorPropRow("Mit Allergie", "\(breakdown.allergies)")
                    inspectorPropRow("Bereits am Tisch", "\(breakdown.assigned)")
                    inspectorPropRow("Kinder", "\(breakdown.kids)")
                }
            }

            InspectorSection("Tags für die Auswahl") {
                bulkTagControls
            }

            VStack(spacing: 8) {
                Button {
                    showingDeleteAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("\(selectedGuestIDs.count) Gäste löschen")
                    }
                    .frame(maxWidth: .infinity)
                }
                .warmButton(.secondary)
                .foregroundStyle(Tokens.Colors.error)

                Button("Auswahl aufheben") {
                    selectedGuestIDs.removeAll()
                    anchorGuestID = nil
                }
                .warmButton(.ghost)
            }
            .padding(20)
        }
        .background(Tokens.Colors.bg2)
    }

    private struct SelectionBreakdown {
        let pinned: Int
        let allergies: Int
        let assigned: Int
        let kids: Int
    }

    private var selectionBreakdown: SelectionBreakdown {
        let s = selectedGuests
        return SelectionBreakdown(
            pinned: s.filter(\.isPinned).count,
            allergies: s.filter(\.hasIntolerances).count,
            assigned: s.filter { $0.table != nil }.count,
            kids: s.filter { $0.ageCategory != .adult }.count
        )
    }

    private func inspectorPropRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .monospacedDigit()
        }
    }

    private func inspectorHeader(_ guest: Guest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Avatar(name: guest.fullName, size: 64,
                   tag: GuestDisplayFormatting.avatarKind(for: guest, tags: tags),
                   diet: GuestDisplayFormatting.dietBadge(for: guest),
                   pinned: guest.isPinned)
            VStack(alignment: .leading, spacing: 2) {
                Text(guest.fullName)
                    .font(Tokens.Typography.displayS)
                    .foregroundStyle(Tokens.Colors.ink)
                Text(guestSubline(guest))
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guestSubline(_ guest: Guest) -> String {
        var parts: [String] = []
        parts.append(guest.partnerAssignment.displayName(for: event))
        if guest.ageCategory != .adult {
            parts.append(guest.ageCategory.rawValue)
        }
        if let age = guest.age {
            parts.append("\(age) Jahre")
        }
        return parts.joined(separator: " · ")
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
