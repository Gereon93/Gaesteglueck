#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Rechte Spalte — Inventar (gruppierte Tische mit Stepper),
/// Auto-Vorschlag und Sitzregeln.
struct RoomInventoryPane: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GuestTable.name) private var tables: [GuestTable]
    @Query private var guests: [Guest]
    @Query private var events: [Event]

    private var guestCount: Int { guests.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                InspectorSection("Inventar") {
                    if tables.isEmpty {
                        Text("Noch keine Tische — wähl links eine Vorlage.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(inventoryGroups, id: \.id) { group in
                                inventoryRow(group: group)
                            }
                        }
                    }
                }

                if guestCount > 0 {
                    InspectorSection("Auto-Vorschlag") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(autoSuggestionText)
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink2)
                                .lineSpacing(3)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Tokens.Colors.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Tokens.Colors.line, lineWidth: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            HStack(spacing: 6) {
                                Button("Anwenden") { applyAutoSuggestion() }
                                    .warmButton(.primary, size: .sm)
                                Button("Anpassen…") {}
                                    .warmButton(.secondary, size: .sm)
                            }
                        }
                    }
                }

                InspectorSection("Sitzregeln") {
                    if let event = events.first {
                        SeatingRulesEditor(event: event)
                    }
                }
            }
        }
        .background(Tokens.Colors.bg2)
    }

    private struct InventoryGroup: Identifiable {
        let id = UUID()
        let shape: TableShape
        let capacity: Int
        let count: Int
        let displayName: String
        let representativeID: UUID
    }

    private var inventoryGroups: [InventoryGroup] {
        let grouped = Dictionary(grouping: tables, by: { GroupKey(shape: $0.shape, capacity: $0.capacity) })
        return grouped.map { key, tablesInGroup in
            let count = tablesInGroup.count
            let display = displayName(for: key, count: count)
            return InventoryGroup(
                shape: key.shape,
                capacity: key.capacity,
                count: count,
                displayName: display,
                representativeID: tablesInGroup.first?.id ?? UUID()
            )
        }
        .sorted { $0.displayName < $1.displayName }
    }

    private struct GroupKey: Hashable {
        let shape: TableShape
        let capacity: Int
    }

    private func displayName(for key: GroupKey, count: Int) -> String {
        let shapeName: String
        switch key.shape {
        case .round: shapeName = "Rund"
        case .rectangular: shapeName = "Tafel"
        case .square: shapeName = "Quadrat"
        }
        return "\(shapeName) · \(key.capacity) Plätze"
    }

    private func inventoryRow(group: InventoryGroup) -> some View {
        HStack(spacing: 10) {
            MiniTableShape(shape: group.shape)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.displayName)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("\(group.capacity) Plätze\(group.count > 1 ? " · \(group.count)× = \(group.capacity * group.count)" : "")")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                counterButton("−") { removeOne(matching: group) }
                Text("\(group.count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .frame(minWidth: 14)
                    .monospacedDigit()
                counterButton("+") { addOne(matching: group) }
            }
        }
        .padding(.vertical, 2)
    }

    private func counterButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .frame(width: 18, height: 18)
                .background(Tokens.Colors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var autoSuggestionText: String {
        guard guestCount > 0 else { return "Sobald Gäste angelegt sind, schlage ich eine Tisch-Konfiguration vor." }
        let mainCount = max(1, guestCount / 8)
        return "Für \(guestCount) Gäste schlage ich vor: 1 Brauttafel · \(mainCount) runde Tische à 8 · 1 Kindertisch."
    }

    // MARK: - Actions

    private func addOne(matching group: InventoryGroup) {
        guard let template = TableTemplate.all.first(where: { $0.shape == group.shape && $0.capacity == group.capacity }) else {
            // Falls keine passende Vorlage: dupliziere ein existierendes Tisch-Set
            if let existing = tables.first(where: { $0.shape == group.shape && $0.capacity == group.capacity }) {
                let position = RoomTableActions.nextPosition(tableCount: tables.count)
                let duplicate = GuestTable(
                    name: "T\(tables.count + 1)",
                    shape: existing.shape,
                    diameter: existing.diameter,
                    width: existing.width,
                    depth: existing.depth,
                    positionX: position.x,
                    positionY: position.y,
                    isChildTable: existing.isChildTable
                )
                modelContext.insert(duplicate)
            }
            return
        }
        RoomTableActions.addTable(from: template, tables: tables, in: modelContext)
    }

    private func removeOne(matching group: InventoryGroup) {
        guard let toRemove = tables.first(where: {
            $0.shape == group.shape && $0.capacity == group.capacity && $0.guests.isEmpty
        }) ?? tables.first(where: { $0.shape == group.shape && $0.capacity == group.capacity }) else { return }
        for guest in toRemove.guests { guest.table = nil }
        modelContext.delete(toRemove)
    }

    private func applyAutoSuggestion() {
        guard guestCount > 0 else { return }
        let mainCount = max(1, guestCount / 8)
        if let bridal = TableTemplate.all.first(where: { $0.shape == .rectangular && $0.capacity == 10 }) {
            RoomTableActions.addTable(from: bridal, tables: tables, in: modelContext)
        }
        if let round8 = TableTemplate.all.first(where: { $0.shape == .round && $0.capacity == 8 }) {
            for _ in 0..<mainCount { RoomTableActions.addTable(from: round8, tables: tables, in: modelContext) }
        }
        if let kids = TableTemplate.all.first(where: { $0.shape == .square }) {
            RoomTableActions.addTable(from: kids, tables: tables, in: modelContext)
        }
    }
}
#endif
